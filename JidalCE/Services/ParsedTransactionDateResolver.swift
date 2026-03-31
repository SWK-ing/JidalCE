import Foundation

enum ParsedTransactionDateResolver {
    static func resolveDate(_ dateString: String?) -> Date {
        guard let dateString, !dateString.isEmpty else { return Date() }

        switch dateString {
        case "오늘":
            return Date()
        case "어제":
            return Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case "그제", "그저께":
            return Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        default:
            return parse(dateString) ?? Date()
        }
    }

    private static func parse(_ raw: String) -> Date? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let slashFormatter = DateFormatter()
        slashFormatter.locale = Locale(identifier: "ko_KR")
        slashFormatter.dateFormat = "yyyy/M/d"

        let koreanFormatter = DateFormatter()
        koreanFormatter.locale = Locale(identifier: "ko_KR")
        koreanFormatter.dateFormat = "yyyy년 M월 d일"

        let cleaned = raw.replacingOccurrences(of: " ", with: "")
        if cleaned.contains("/") {
            return slashFormatter.date(from: "\(currentYear)/\(cleaned)")
        }
        if cleaned.contains("월"), cleaned.contains("일") {
            return koreanFormatter.date(from: "\(currentYear)년 \(cleaned)")
        }
        return nil
    }
}
