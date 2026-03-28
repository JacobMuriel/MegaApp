import SwiftUI
import UIKit

// MARK: - Shake gesture detection
//
// UIKit is required because SwiftUI has no built-in shake API.
// A hidden UIViewController becomes first responder so it receives
// `motionEnded(_:with:)` callbacks from the system.

private final class ShakeViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
    }
}

// MARK: - UIViewControllerRepresentable bridge

private struct ShakeRepresentable: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

// MARK: - ViewModifier

struct ShakeToRecoverModifier: ViewModifier {
    let onShake: () -> Void

    func body(content: Content) -> some View {
        content.background(
            // Zero-size frame so the representable is invisible
            ShakeRepresentable(onShake: onShake)
                .frame(width: 0, height: 0)
        )
    }
}

// MARK: - View extension

extension View {
    /// Calls `action` whenever the user shakes the device.
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeToRecoverModifier(onShake: action))
    }
}
