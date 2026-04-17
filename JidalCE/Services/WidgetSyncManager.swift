import Foundation
import WidgetKit

struct WidgetSyncManager {
    static let suiteName = "group.com.JidalCE.app"

    private let defaults = UserDefaults(suiteName: suiteName)

    func update(groupID: String, ledgerName: String, ledgerIcon: String, balance: Int) {
        defaults?.set(groupID, forKey: "widgetCalendarId")
        defaults?.set(ledgerName, forKey: "widgetLedgerName")
        defaults?.set(ledgerIcon, forKey: "widgetLedgerIcon")
        defaults?.set(balance, forKey: "widgetBalance")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clear() {
        defaults?.removeObject(forKey: "widgetCalendarId")
        defaults?.removeObject(forKey: "widgetLedgerName")
        defaults?.removeObject(forKey: "widgetLedgerIcon")
        defaults?.removeObject(forKey: "widgetBalance")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
