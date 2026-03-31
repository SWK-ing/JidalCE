import Observation
import Foundation

@MainActor
@Observable
final class BudgetManager {
    func budget(for ledgerName: String) -> Budget {
        guard let data = UserDefaults.standard.data(forKey: key(for: ledgerName)),
              let budget = try? JSONDecoder().decode(Budget.self, from: data) else {
            return .empty
        }
        return budget
    }

    func save(_ budget: Budget, for ledgerName: String) {
        guard let data = try? JSONEncoder().encode(budget) else { return }
        UserDefaults.standard.set(data, forKey: key(for: ledgerName))
    }

    private func key(for ledgerName: String) -> String {
        "budget_\(ledgerName)"
    }
}
