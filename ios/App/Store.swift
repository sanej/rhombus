import Foundation
import SwiftUI
import RhombusCore

@MainActor
final class Store: ObservableObject {
    @Published var state = AppState()
    @Published var message = "Tap the mic and say “Add product Orbit”."
    @Published var isError = false

    private var apiURL: String { UserDefaults.standard.string(forKey: "apiURL") ?? "" }
    private var apiToken: String { UserDefaults.standard.string(forKey: "apiToken") ?? "" }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: String]? = nil) async throws -> T {
        guard let base = URL(string: apiURL), !apiURL.isEmpty else { throw StoreError.notConfigured }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer " + apiToken, forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw StoreError.server }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private struct OK: Decodable {}

    func refresh() async {
        do { state = try await request("api/state") }
        catch { report(error) }
    }

    func handle(transcript: String) async {
        let intent = VoiceParser.parse(transcript)
        do {
            switch intent {
            case .addProduct(let name):
                let p: Product = try await request("api/products", method: "POST", body: ["name": name.capitalized])
                withAnimation(.spring()) { state.products.append(p) }
                say("Added product \(p.name).")
            case .addFeature(let title, let productName, let status):
                guard let product = resolveProduct(productName) else {
                    return say(state.products.isEmpty ? "Add a product first." : "Which product? Say “add feature \(title) to” and the product name.", error: true)
                }
                var f: Feature = try await request("api/features", method: "POST",
                                                   body: ["productId": product.id, "title": title.capitalized, "status": status.rawValue])
                f.status = status
                withAnimation(.spring()) { state.features.append(f) }
                say("Added \(f.title) to \(product.name).")
            case .setStatus(let name, let status):
                guard let f = Matcher.best(name, in: state.features, name: { $0.title }) else {
                    return say("I couldn't find a feature called “\(name)”.", error: true)
                }
                let _: Feature = try await request("api/features/\(f.id)", method: "PATCH", body: ["status": status.rawValue])
                withAnimation(.spring()) {
                    if let i = state.features.firstIndex(where: { $0.id == f.id }) { state.features[i].status = status }
                }
                say("\(f.title) is now \(status.label).")
            case .deleteProduct(let name):
                guard let p = Matcher.best(name, in: state.products, name: { $0.name }) else {
                    return say("I couldn't find a product called “\(name)”.", error: true)
                }
                let _: OK = try await request("api/products/\(p.id)", method: "DELETE")
                withAnimation(.spring()) {
                    state.products.removeAll { $0.id == p.id }
                    state.features.removeAll { $0.productId == p.id }
                }
                say("Deleted \(p.name).")
            case .deleteFeature(let title):
                guard let f = Matcher.best(title, in: state.features, name: { $0.title }) else {
                    return say("I couldn't find a feature called “\(title)”.", error: true)
                }
                let _: OK = try await request("api/features/\(f.id)", method: "DELETE")
                withAnimation(.spring()) { state.features.removeAll { $0.id == f.id } }
                say("Deleted \(f.title).")
            case .unknown:
                say("Sorry, I didn't get that: “\(transcript)”.", error: true)
            }
        } catch { report(error) }
    }

    private func resolveProduct(_ name: String?) -> Product? {
        if let name { return Matcher.best(name, in: state.products, name: { $0.name }) }
        return state.products.count == 1 ? state.products.first : nil
    }

    private func say(_ text: String, error: Bool = false) { message = text; isError = error }

    private func report(_ error: Error) {
        if let e = error as? StoreError { say(e.description, error: true) }
        else { say("Network problem. Please try again.", error: true) }
    }
}

enum StoreError: Error, CustomStringConvertible {
    case notConfigured, server
    var description: String {
        switch self {
        case .notConfigured: return "Open Settings and enter your server URL and token."
        case .server: return "The server rejected the request."
        }
    }
}
