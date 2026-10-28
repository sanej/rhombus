import Foundation

/// A structured action extracted from a spoken sentence.
public enum VoiceIntent: Equatable, Sendable {
    case addProduct(name: String)
    case addFeature(title: String, product: String?, status: FeatureStatus)
    case setStatus(feature: String, status: FeatureStatus)
    case deleteProduct(name: String)
    case deleteFeature(title: String)
    case unknown(String)
}

public enum VoiceParser {
    private static let statusPhrases: [(String, FeatureStatus)] = [
        ("in progress", .inProgress), ("in-progress", .inProgress), ("started", .inProgress),
        ("started working", .inProgress), ("working", .inProgress),
        ("blocked", .blocked), ("stuck", .blocked),
        ("done", .done), ("complete", .done), ("completed", .done), ("finished", .done),
        ("shipped", .done), ("launched", .done),
        ("planned", .planned), ("idea", .idea), ("backlog", .idea),
    ]

    public static func parse(_ raw: String) -> VoiceIntent {
        let text = normalize(raw)
        guard !text.isEmpty else { return .unknown(raw) }

        if let rest = strip(text, prefixes: ["delete product ", "remove product "]) {
            return .deleteProduct(name: rest)
        }
        if let rest = strip(text, prefixes: ["delete feature ", "remove feature "]) {
            return .deleteFeature(title: rest)
        }
        if let rest = strip(text, prefixes: ["add product ", "new product ", "create product ", "add a product ",
                                             "add a new product ", "create a product ", "create a new product "]) {
            let name = stripCalled(rest)
            return name.isEmpty ? .unknown(raw) : .addProduct(name: name)
        }
        if let rest = strip(text, prefixes: ["add feature ", "new feature ", "create feature ", "add a feature ",
                                             "add a new feature ", "create a feature "]) {
            let (title, product) = splitProduct(rest)
            return title.isEmpty ? .unknown(raw) : .addFeature(title: title, product: product, status: .idea)
        }

        // "mark X as done", "set X to in progress"
        if let rest = strip(text, prefixes: ["mark ", "set ", "move ", "update "]) {
            for sep in [" as ", " to ", " is "] {
                if let r = rest.range(of: sep, options: .backwards),
                   let status = status(from: String(rest[r.upperBound...])) {
                    let feature = String(rest[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !feature.isEmpty { return .setStatus(feature: stripFeatureWord(feature), status: status) }
                }
            }
        }
        // "X is done", "X is blocked"
        if let r = text.range(of: " is ", options: .backwards),
           let status = status(from: String(text[r.upperBound...])) {
            let feature = String(text[..<r.lowerBound])
            if !feature.isEmpty { return .setStatus(feature: stripFeatureWord(feature), status: status) }
        }
        return .unknown(raw)
    }

    static func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
        let allowed = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" ? Character($0) : " " }
        return String(allowed).split(separator: " ").joined(separator: " ")
    }

    private static func strip(_ text: String, prefixes: [String]) -> String? {
        for p in prefixes.sorted(by: { $0.count > $1.count }) where text.hasPrefix(p) {
            let rest = String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            return rest
        }
        return nil
    }

    private static func stripCalled(_ s: String) -> String {
        for p in ["called ", "named "] where s.hasPrefix(p) { return String(s.dropFirst(p.count)) }
        return s
    }

    private static func stripFeatureWord(_ s: String) -> String {
        s.hasPrefix("feature ") ? String(s.dropFirst(8)) : s
    }

    private static func splitProduct(_ s: String) -> (String, String?) {
        for sep in [" to product ", " to ", " for product ", " for ", " in product ", " in "] {
            if let r = s.range(of: sep, options: .backwards) {
                let title = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let product = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !product.isEmpty { return (stripCalled(title), product) }
            }
        }
        return (stripCalled(s), nil)
    }

    private static func status(from s: String) -> FeatureStatus? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return statusPhrases.first(where: { $0.0 == t })?.1
    }
}
