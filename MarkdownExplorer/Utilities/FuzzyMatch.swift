import Foundation

enum FuzzyMatch {
    static func score(query: String, candidate: String) -> Int? {
        if query.isEmpty { return 0 }
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        var qi = 0
        var score = 0
        var streak = 0
        var prevMatch = -1

        for (ci, ch) in c.enumerated() {
            if qi >= q.count { break }
            if ch == q[qi] {
                score += 10
                if prevMatch >= 0 && ci == prevMatch + 1 {
                    streak += 1
                    score += streak * 4
                } else {
                    streak = 0
                }
                if ci == 0 || !c[ci - 1].isLetter {
                    score += 8
                }
                prevMatch = ci
                qi += 1
            }
        }

        guard qi == q.count else { return nil }
        score -= max(0, c.count - q.count) / 4
        return score
    }
}
