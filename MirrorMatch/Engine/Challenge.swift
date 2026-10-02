import Foundation

/// Challenges travel inside links, so friends can play the exact same moves without any account or server.
enum ChallengeKind: String, Codable { case run, custom }

struct Challenge: Hashable, Codable, Identifiable {
    var id: String { "\(kind.rawValue)-\(seed)-\(name)-\(score)" }
    var kind: ChallengeKind = .run
    var seed: UInt64 = 0
    var name: String
    var score: Int = 0
    var customPoints: [CGPoint] = []

    static let host = "https://marco-p-keller.github.io/mirror-match/c/"
    static let appStoreURL = "https://apps.apple.com/app/mirror-match-copy-battle/id0000000000"

    var webURL: URL {
        var c = URLComponents(string: Challenge.host)!
        c.queryItems = queryItems
        return c.url!
    }

    var schemeURL: URL {
        var c = URLComponents()
        c.scheme = "mirrormatch"
        c.host = "c"
        c.queryItems = queryItems
        return c.url!
    }

    private var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "k", value: kind == .run ? "r" : "m"), URLQueryItem(name: "n", value: name)]
        if kind == .run {
            items.append(URLQueryItem(name: "s", value: String(seed, radix: 36)))
            items.append(URLQueryItem(name: "p", value: String(score)))
        } else {
            items.append(URLQueryItem(name: "d", value: Challenge.encode(customPoints)))
        }
        return items
    }

    static func parse(_ text: String) -> Challenge? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // allow a pasted message that contains the link somewhere
        let candidate = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init).first { $0.contains("?") && ($0.contains("k=") || $0.contains("s=")) } ?? trimmed
        guard let comps = URLComponents(string: candidate) else { return nil }
        return parse(comps)
    }

    static func parse(_ url: URL) -> Challenge? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return parse(comps)
    }

    private static func parse(_ comps: URLComponents) -> Challenge? {
        let q = Dictionary((comps.queryItems ?? []).compactMap { i in i.value.map { (i.name, $0) } }, uniquingKeysWith: { a, _ in a })
        let name = String((q["n"] ?? "A friend").prefix(18))
        if q["k"] == "m", let d = q["d"], let pts = decode(d) {
            return Challenge(kind: .custom, seed: 0, name: name, score: 0, customPoints: pts)
        }
        if let s = q["s"], let seed = UInt64(s, radix: 36) {
            return Challenge(kind: .run, seed: seed, name: name, score: Int(q["p"] ?? "0") ?? 0)
        }
        return nil
    }

    static func encode(_ pts: [CGPoint]) -> String {
        let n = 48
        let r = Scoring.resample(pts, count: n)
        var bytes: [UInt8] = []
        for p in r {
            bytes.append(UInt8(max(0, min(255, (p.x * 255).rounded()))))
            bytes.append(UInt8(max(0, min(255, (p.y * 255).rounded()))))
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ s: String) -> [CGPoint]? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let d = Data(base64Encoded: b), d.count >= 8, d.count % 2 == 0 else { return nil }
        let bytes = [UInt8](d)
        var out: [CGPoint] = []
        for i in stride(from: 0, to: bytes.count, by: 2) {
            out.append(CGPoint(x: Double(bytes[i]) / 255, y: Double(bytes[i + 1]) / 255))
        }
        return out
    }

    var shareText: String {
        switch kind {
        case .run:
            return "🪞 I scored \(score)/500 on Mirror Match. Can you copy these moves better than me? \(webURL.absoluteString)"
        case .custom:
            return "🪞 I made a move for you to copy in Mirror Match. Bet you can't match it: \(webURL.absoluteString)"
        }
    }
}
