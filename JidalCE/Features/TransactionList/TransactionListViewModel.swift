import Foundation

@MainActor
@Observable
final class TransactionListViewModel {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }
}
