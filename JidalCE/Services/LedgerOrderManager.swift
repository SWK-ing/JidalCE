import Foundation

struct LedgerOrderManager {
    func orderedNames(for groupID: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(for: groupID)) ?? []
    }

    func saveOrder(_ names: [String], for groupID: String) {
        UserDefaults.standard.set(names, forKey: key(for: groupID))
    }

    private func key(for groupID: String) -> String {
        "ledgerOrder_\(groupID)"
    }
}
