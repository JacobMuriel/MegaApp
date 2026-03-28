import Foundation
import Observation

// MARK: - SearchViewModel
//
// Drives the Kroger product search flow:
//   1. User enters zip → fetch store list from proxy
//   2. User picks a store → stored as `selectedStore`
//   3. User searches for a product → fetch product list
//   4. User taps "Add" on a product → append to cart via CartViewModel

@Observable
@MainActor
final class SearchViewModel {

    // MARK: State

    var zip:               String = ""
    var query:             String = ""
    var stores:            [KrogerStore]  = []
    var selectedStore:     KrogerStore?   = nil
    var products:          [KrogerProduct] = []
    var isLoadingStores    = false
    var isLoadingProducts  = false
    var errorMessage:      String? = nil

    private let proxyBase: String = Bundle.main.infoDictionary?["KROGER_PROXY_URL"] as? String ?? "http://localhost:3001"

    // MARK: - Store fetch

    func fetchStores() async {
        guard !zip.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoadingStores = true
        errorMessage    = nil
        defer { isLoadingStores = false }

        do {
            var components       = URLComponents(string: "\(proxyBase)/stores")!
            components.queryItems = [URLQueryItem(name: "zip", value: zip)]
            let (data, _)        = try await URLSession.shared.data(from: components.url!)

            struct Resp: Decodable { let data: [KrogerStore] }
            stores = try JSONDecoder().decode(Resp.self, from: data).data
        } catch {
            // Fall back to mock so the UI is usable without the proxy running
            stores       = mockStores()
            errorMessage = "Using mock data — proxy may not be running on :3001."
        }
    }

    // MARK: - Product search

    func searchProducts() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoadingProducts = true
        errorMessage      = nil
        defer { isLoadingProducts = false }

        do {
            var components        = URLComponents(string: "\(proxyBase)/products/search")!
            var items: [URLQueryItem] = [URLQueryItem(name: "query", value: query)]
            if let store = selectedStore {
                items.append(URLQueryItem(name: "locationId", value: store.id))
            }
            components.queryItems = items
            let (data, _)         = try await URLSession.shared.data(from: components.url!)

            struct Resp: Decodable { let data: [KrogerProduct] }
            products = try JSONDecoder().decode(Resp.self, from: data).data
        } catch {
            products     = mockProducts(for: query)
            errorMessage = "Using mock data — proxy may not be running on :3001."
        }
    }

    // MARK: - Mock fallback (mirrors server.js mock data)

    private func mockStores() -> [KrogerStore] {
        [
            KrogerStore(id: "01400943", name: "Kroger", address: "100 Main St", city: "Atlanta", state: "GA", zip: zip),
            KrogerStore(id: "01400944", name: "Fred Meyer", address: "200 Oak Ave", city: "Atlanta", state: "GA", zip: zip),
        ]
    }

    private func mockProducts(for query: String) -> [KrogerProduct] {
        // Generic mock products — enough to verify the UI layout
        [
            KrogerProduct(id: "mock-1", name: "Organic \(query.capitalized)", brand: "Simple Truth", priceCents: 399, imageURL: nil, aisleNumber: "A3", calories: 120, proteinG: 5, carbsG: 18, fatG: 3),
            KrogerProduct(id: "mock-2", name: "\(query.capitalized) - Private Selection", brand: "Kroger", priceCents: 299, imageURL: nil, aisleNumber: "B7", calories: 150, proteinG: 8, carbsG: 20, fatG: 4),
            KrogerProduct(id: "mock-3", name: "Fresh \(query.capitalized)", brand: nil, priceCents: 499, imageURL: nil, aisleNumber: "C2", calories: 80, proteinG: 3, carbsG: 12, fatG: 1),
        ]
    }
}
