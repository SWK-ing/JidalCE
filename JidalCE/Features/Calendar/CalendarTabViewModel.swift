import Foundation

@MainActor
@Observable
final class CalendarTabViewModel {
    let appState: AppState
    var selectedDate = Date()

    init(appState: AppState) {
        self.appState = appState
    }

    var monthDays: [Date] {
        appState.currentMonth.calendarGridDays
    }

    var selectedMonthTitle: String {
        appState.currentMonth.yearMonthDisplayText
    }
}
