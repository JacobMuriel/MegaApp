import SwiftUI
import SwiftData

// MARK: - PantryView
//
// Pantry item list with ok/low/out status indicators.
// Voice update flow: mic button → AVAudioRecorder → Whisper → GPT → confirmation toast.
// The 20-second approve/undo window is surfaced as a floating banner at the bottom.

struct PantryView: View {
    @Query(sort: \PantryItem.name) private var items: [PantryItem]
    @Environment(\.modelContext) private var modelContext

    @State private var vm             = PantryViewModel()
    @State private var showAddItem    = false
    @State private var statusFilter:  PantryStatus? = nil  // nil = show all

    private var filteredItems: [PantryItem] {
        guard let f = statusFilter else { return items }
        return items.filter { $0.status == f.rawValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                statusFilterBar
                    .padding(.vertical, Theme.Spacing.sm)

                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }

            // Approve toast overlay
            if vm.showApproveToast {
                approveToast
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Error snackbar
            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Cartly.danger, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.button))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, vm.showApproveToast ? 80 : Theme.Spacing.sm)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showApproveToast)
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
        .navigationTitle("Pantry")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Voice mic button
                Button {
                    if vm.isRecording {
                        vm.stopAndProcess(context: modelContext, items: items)
                    } else {
                        vm.startRecording()
                    }
                } label: {
                    Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundStyle(vm.isRecording ? Theme.Cartly.danger : Theme.Cartly.primaryAccent)
                        .symbolEffect(.pulse, isActive: vm.isRecording)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddItem = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddPantryItemSheet()
        }
        .overlay {
            if vm.isProcessing {
                ProgressView("Processing voice update…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
            }
        }
    }

    // MARK: - Subviews

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                CartlyFilterChip(title: "All", isSelected: statusFilter == nil) {
                    statusFilter = nil
                }
                ForEach(PantryStatus.allCases, id: \.self) { s in
                    CartlyFilterChip(title: s.label, isSelected: statusFilter == s) {
                        statusFilter = s
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var itemList: some View {
        List {
            ForEach(filteredItems) { item in
                PantryItemRow(item: item)
            }
            .onDelete { offsets in
                offsets.map { filteredItems[$0] }.forEach { modelContext.delete($0) }
                try? modelContext.save()
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "cabinet")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Cartly.textSecondary)
            Text("Pantry is empty")
                .font(.headline)
                .foregroundStyle(Theme.Cartly.textSecondary)
            Text("Tap + to add items or use the mic for a voice update.")
                .font(.subheadline)
                .foregroundStyle(Theme.Cartly.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var approveToast: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.Cartly.primaryAccent)
                Text("Voice update ready")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(vm.toastCountdown)s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.Cartly.textSecondary)
            }
            if !vm.transcription.isEmpty {
                Text("\"\(vm.transcription)\"")
                    .font(.caption)
                    .foregroundStyle(Theme.Cartly.textSecondary)
                    .lineLimit(2)
            }
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(vm.pendingChanges) { intent in
                    Text(intent.action == "remove" ? "−\(intent.itemName)" : "+\(intent.itemName)")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            intent.action == "remove"
                                ? Theme.Cartly.danger.opacity(0.15)
                                : Theme.Cartly.success.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(intent.action == "remove" ? Theme.Cartly.danger : Theme.Cartly.success)
                }
                Spacer()
            }
            HStack(spacing: Theme.Spacing.sm) {
                Button("Approve") {
                    withAnimation { vm.applyChanges(context: modelContext, items: items) }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.Cartly.primaryAccent, in: Capsule())

                Button("Dismiss") {
                    withAnimation { vm.dismissToast() }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.Cartly.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

// MARK: - PantryItemRow

private struct PantryItemRow: View {
    @Bindable var item: PantryItem

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(Theme.Cartly.textPrimary)
                HStack(spacing: 4) {
                    if let amount = item.amount {
                        Text(Format.decimal(amount, places: 1))
                            .font(.caption)
                            .foregroundStyle(Theme.Cartly.textSecondary)
                    }
                    if let unit = item.unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(Theme.Cartly.textSecondary)
                    }
                    if let cat = item.category {
                        Text("• \(cat)")
                            .font(.caption)
                            .foregroundStyle(Theme.Cartly.textSecondary)
                    }
                }
            }

            Spacer()

            // Status picker
            Menu {
                ForEach(PantryStatus.allCases, id: \.self) { s in
                    Button(s.label) { item.status = s.rawValue }
                }
            } label: {
                Text(item.statusEnum.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch item.statusEnum {
        case .ok:  return Theme.Cartly.success
        case .low: return Theme.Cartly.warning
        case .out: return Theme.Cartly.danger
        }
    }
}

// MARK: - AddPantryItemSheet

private struct AddPantryItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var name     = ""
    @State private var amount   = ""
    @State private var unit     = ""
    @State private var category = ""
    @State private var status   = PantryStatus.ok

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("Unit (e.g. cups)", text: $unit)
                    }
                    TextField("Category (optional)", text: $category)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(PantryStatus.allCases, id: \.self) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let item = PantryItem(
            name:     name.trimmingCharacters(in: .whitespaces),
            amount:   Double(amount),
            unit:     unit.isEmpty ? nil : unit,
            status:   status.rawValue,
            category: category.isEmpty ? nil : category
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - CartlyFilterChip (shared within Cartly)

struct CartlyFilterChip: View {
    let title:      String
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Theme.Cartly.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs + 2)
                .background(
                    isSelected ? Theme.Cartly.primaryAccent : Color(.systemGray5),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
