import Foundation

enum HistorySerializer {
    nonisolated private static let separator = "──────────"

    static func serialize(entries: [HistoryEntry], monthText: String, yearMonth: String) -> String {
        let lines = entries.map { entry in
            "\(entry.date) \(entry.time) \(entry.action.rawValue) | \(entry.memo) \(entry.amount) | \(entry.by)"
        }
        let counts = Dictionary(grouping: entries, by: \.action).mapValues(\.count)
        let summary = "\(monthText): 추가 \(counts[.added, default: 0])건, 수정 \(counts[.modified, default: 0])건, 삭제 \(counts[.deleted, default: 0])건"
        return (lines + [separator, summary, separator, "#history:\(yearMonth)"]).joined(separator: "\n")
    }

    nonisolated static func parse(_ notes: String?) -> [HistoryEntry] {
        guard let notes, !notes.isEmpty else { return [] }
        return notes
            .split(separator: "\n")
            .map(String.init)
            .prefix { !$0.hasPrefix(separator) }
            .compactMap(parseLine)
    }

    nonisolated static func parseLine(_ line: String) -> HistoryEntry? {
        let firstSplit = line.components(separatedBy: " | ")
        guard firstSplit.count == 3 else { return nil }
        let header = firstSplit[0].split(separator: " ", maxSplits: 2).map(String.init)
        guard header.count == 3, let action = HistoryAction(rawValue: header[2]) else { return nil }
        let detail = firstSplit[1]
        guard let amountRange = detail.range(of: " [+-]?\\d[\\d,]*(→[+-]?\\d[\\d,]*)?원", options: .regularExpression) else {
            return nil
        }
        let memo = detail[..<amountRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let amount = detail[amountRange].trimmingCharacters(in: .whitespaces)
        return HistoryEntry(
            date: header[0],
            time: header[1],
            action: action,
            memo: memo,
            amount: amount,
            by: firstSplit[2]
        )
    }
}
