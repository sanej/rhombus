import Foundation

/// Fuzzy name matching so speech-recognition variance still resolves to the right item.
public enum Matcher {
    public static func best<T>(_ query: String, in items: [T], name: (T) -> String) -> T? {
        let q = VoiceParser.normalize(query)
        guard !q.isEmpty else { return nil }
        var best: (T, Int)?
        for item in items {
            let n = VoiceParser.normalize(name(item))
            let score: Int
            if n == q { score = 100 }
            else if n.contains(q) || q.contains(n) { score = 80 }
            else {
                let a = Set(q.split(separator: " ")), b = Set(n.split(separator: " "))
                let overlap = a.intersection(b).count
                score = overlap == 0 ? 0 : 40 + 40 * overlap / max(a.count, b.count)
            }
            if score >= 50, score > (best?.1 ?? 0) { best = (item, score) }
        }
        return best?.0
    }
}
