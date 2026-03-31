import Foundation

struct Budget: Codable, Hashable {
    var monthlyLimit: Int
    var categoryLimits: [String: Int]

    static let empty = Budget(monthlyLimit: 0, categoryLimits: [:])
}

struct BudgetProgress: Hashable {
    let title: String
    let spent: Int
    let limit: Int

    var ratio: Double {
        guard limit > 0 else { return 0 }
        return min(Double(spent) / Double(limit), 1.2)
    }

    var statusText: String {
        guard limit > 0 else { return "미설정" }
        let percent = Int((Double(spent) / Double(limit)) * 100)
        if percent >= 100 { return "초과" }
        if percent >= 80 { return "주의" }
        return "정상"
    }
}

struct MonthlyFlowData: Identifiable, Hashable {
    let id = UUID()
    let month: String
    let expense: Int
    let income: Int
}

struct CategoryAmount: Identifiable, Hashable {
    var id: String { category }
    let category: String
    let amount: Int
}
