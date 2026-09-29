import Foundation

/// Small, deterministic search helper shared by task-list surfaces.
public enum TaskSearch {
    /// Every whitespace-delimited query term must occur in at least one field.
    /// Matching is case- and diacritic-insensitive while preserving localized text.
    public static func matches(_ query: String, in fields: [String]) -> Bool {
        let tokens = query
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard !tokens.isEmpty else { return true }

        let normalizedFields = fields.map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        return tokens.allSatisfy { token in
            normalizedFields.contains { $0.contains(token) }
        }
    }
}
