import Foundation

struct TransactionRecord: Hashable {
    let id: String
    let amount: Int
    let category: String
    let memo: String
    let time: String
    let by: String
}

enum NoteSerializerError: LocalizedError {
    case malformedDataLine(String)
    case malformedIdentifierLine

    var errorDescription: String? {
        switch self {
        case .malformedDataLine(let line):
            return "거래 메모 파싱에 실패했습니다: \(line)"
        case .malformedIdentifierLine:
            return "거래 ID 목록 형식이 올바르지 않습니다."
        }
    }
}

enum NoteSerializer {
    private static let separator = "──────────"

    static func serialize(records: [TransactionRecord]) -> String {
        guard !records.isEmpty else { return "" }
        var lines: [String] = []
        for record in records {
            lines.append(record.memo)
            lines.append("  \(signedAmountString(record.amount))원 | \(record.category) | \(record.time) | \(record.by)")
        }
        lines.append(separator)
        let expenseCount = records.filter { $0.amount < 0 }.count
        let expenseTotal = records.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let incomeCount = records.filter { $0.amount >= 0 }.count
        let incomeTotal = records.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let summaryParts = [
            expenseCount > 0 ? "지출 \(formattedAmount(expenseTotal))원 (\(expenseCount)건)" : nil,
            incomeCount > 0 ? "수입 \(formattedAmount(incomeTotal))원 (\(incomeCount)건)" : nil
        ].compactMap { $0 }
        lines.append(summaryParts.isEmpty ? "거래 없음" : summaryParts.joined(separator: " · "))
        lines.append(separator)
        lines.append(records.map { "#\($0.id)" }.joined(separator: " "))
        return lines.joined(separator: "\n")
    }

    static func parse(_ notes: String?) throws -> [TransactionRecord] {
        guard let notes, !notes.isEmpty else { return [] }

        let lines = notes.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var pairs: [(String, String)] = []
        var currentMemo: String?

        for line in lines {
            if line.hasPrefix(separator) {
                break
            }
            if line.hasPrefix("  ") {
                guard let memo = currentMemo else { continue }
                pairs.append((memo, line))
                currentMemo = nil
            } else if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentMemo = line
            }
        }

        guard let idLine = lines.last(where: { $0.hasPrefix("#") }) else {
            throw NoteSerializerError.malformedIdentifierLine
        }
        let ids = idLine.split(separator: " ").map { $0.replacingOccurrences(of: "#", with: "") }
        guard ids.count == pairs.count, Set(ids).count == ids.count else {
            throw NoteSerializerError.malformedIdentifierLine
        }

        return try zip(ids, pairs).map { id, pair in
            let components = splitDataLine(pair.1)
            guard components.count == 4 else {
                throw NoteSerializerError.malformedDataLine(pair.1)
            }
            let amount = try parseAmount(components[0])
            return TransactionRecord(
                id: id,
                amount: amount,
                category: components[1],
                memo: pair.0,
                time: components[2],
                by: components[3]
            )
        }
    }

    static func makeTransactionID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(4)).lowercased()
    }

    static func signedAmountString(_ amount: Int) -> String {
        let sign = amount >= 0 ? "+" : "-"
        return "\(sign)\(formattedAmount(abs(amount)))"
    }

    private static func splitDataLine(_ line: String) -> [String] {
        line
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseAmount(_ raw: String) throws -> Int {
        let sanitized = raw
            .replacingOccurrences(of: "원", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        if sanitized.hasPrefix("+") {
            return Int(sanitized.dropFirst()) ?? 0
        }
        if sanitized.hasPrefix("-") {
            return -(Int(sanitized.dropFirst()) ?? 0)
        }
        guard let amount = Int(sanitized) else {
            throw NoteSerializerError.malformedDataLine(raw)
        }
        return amount
    }

    private static func formattedAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
