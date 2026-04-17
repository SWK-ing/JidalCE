import EventKit
import Observation
import SwiftUI
import UIKit

enum AppRoute {
    case calendarPermission
    case groupSetup
    case main
}

@MainActor
@Observable
final class AppState {
    var route: AppRoute = .calendarPermission
    var isLoading = false
    var errorMessage: String?

    var selectedGroup: JidalGroup?
    var availableGroups: [JidalGroup] = []
    var ledgers: [Ledger] = []
    var selectedLedgerName: String?
    var monthTransactions: [Transaction] = []
    var recentHistory: [HistoryEntry] = []
    var currentBalance: Int = 0
    var currentMonth = Date()
    var isBookClosingInProgress = false
    var bookClosingProgressMonths: [String] = []
    var bookClosingResultText: String?
    var recentMonthlyFlows: [MonthlyFlowData] = []
    var budgetProgress: [BudgetProgress] = []

    let categoryManager = CategoryManager()
    let budgetManager = BudgetManager()
    let aiService = AIService()
    let promptSettingsManager = PromptSettingsManager()
    private let ledgerOrderManager = LedgerOrderManager()
    private let widgetSyncManager = WidgetSyncManager()

    private let calendarStore: CalendarStore
    private let groupRepository: GroupRepository
    private let ledgerRepository: LedgerRepository
    private let historyRepository: HistoryRepository
    private let transactionRepository: TransactionRepository
    private let snapshotRepository: SnapshotRepository
    private let balanceCalculator: BalanceCalculator

    init() {
        let calendarStore = CalendarStore.shared
        self.calendarStore = calendarStore
        self.groupRepository = GroupRepository(store: calendarStore)
        self.ledgerRepository = LedgerRepository(store: calendarStore)
        self.historyRepository = HistoryRepository(store: calendarStore)
        self.transactionRepository = TransactionRepository(
            store: calendarStore,
            historyRepository: historyRepository
        )
        self.snapshotRepository = SnapshotRepository(
            store: calendarStore,
            transactionRepository: transactionRepository
        )
        self.balanceCalculator = BalanceCalculator(
            transactionRepository: transactionRepository,
            snapshotRepository: snapshotRepository
        )

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: calendarStore.eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reloadAfterExternalChange()
            }
        }
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }

        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            await loadGroupsAndRoute()
        case .notDetermined:
            route = .calendarPermission
        default:
            route = .calendarPermission
        }
    }

    func requestCalendarAccess() async {
        isLoading = true
        defer { isLoading = false }

        let granted = await calendarStore.requestAccess()
        if granted {
            await loadGroupsAndRoute()
        } else {
            errorMessage = "캘린더 권한이 필요합니다."
            route = .calendarPermission
        }
    }

    func loadGroupsAndRoute() async {
        availableGroups = groupRepository.fetchGroups()
        if let restored = groupRepository.restoreSelectedGroup(from: availableGroups) {
            selectedGroup = restored
            route = .main
            await reloadMainData()
        } else {
            widgetSyncManager.clear()
            route = availableGroups.isEmpty ? .groupSetup : .groupSetup
        }
    }

    func createGroup(name: String, color: Color) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let group = try groupRepository.createGroup(name: name, color: UIColor(color).cgColor)
            selectedGroup = group
            availableGroups = groupRepository.fetchGroups()
            groupRepository.persistSelectedGroup(group.id)
            route = .main
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectExistingGroup(_ group: JidalGroup) async {
        selectedGroup = group
        groupRepository.persistSelectedGroup(group.id)
        route = .main
        await reloadMainData()
    }

    func reloadMainData() async {
        guard let group = selectedGroup else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            ledgers = try ledgerRepository.fetchLedgers(in: group)
            ledgers = orderedLedgers(ledgers, for: group.id)
            if selectedLedgerName == nil || !ledgers.contains(where: { $0.name == selectedLedgerName }) {
                selectedLedgerName = groupRepository.restoreSelectedLedger(from: ledgers)
            }
            groupRepository.persistSelectedLedger(selectedLedgerName)

            if let ledgerName = selectedLedgerName {
                try snapshotRepository.ensureAutomaticSnapshot(for: ledgerName, in: group)
                monthTransactions = try transactionRepository.fetchTransactions(
                    inMonth: currentMonth,
                    ledgerName: ledgerName,
                    group: group
                ).sortedByDateTimeDescending()
                recentHistory = try historyRepository.fetchRecentEntries(
                    ledgerName: ledgerName,
                    group: group,
                    anchorMonth: currentMonth
                )
                currentBalance = try balanceCalculator.currentBalance(
                    ledgerName: ledgerName,
                    in: group,
                    anchorDate: currentMonth
                )
                recentMonthlyFlows = try buildMonthlyFlowData(ledgerName: ledgerName, group: group)
                refreshBudget()
                syncWidgetData(group: group, ledgerName: ledgerName)
            } else {
                monthTransactions = []
                recentHistory = []
                currentBalance = 0
                recentMonthlyFlows = []
                budgetProgress = []
                widgetSyncManager.clear()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addLedger(name: String, icon: String, color: String, currency: String) async {
        guard let group = selectedGroup else { return }
        do {
            try ledgerRepository.saveLedger(
                Ledger(name: name, icon: icon, color: color, currency: currency, sortOrder: ledgers.count),
                in: group
            )
            selectedLedgerName = name
            groupRepository.persistSelectedLedger(name)
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteLedger(_ ledger: Ledger) async {
        guard let group = selectedGroup else { return }
        do {
            try ledgerRepository.deleteLedger(named: ledger.name, in: group)
            if selectedLedgerName == ledger.name {
                selectedLedgerName = nil
            }
            groupRepository.persistSelectedLedger(selectedLedgerName)
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTransaction(_ draft: TransactionDraft) async {
        guard let group = selectedGroup else { return }
        do {
            let ledgerName = draft.ledgerName.isEmpty ? (selectedLedgerName ?? "") : draft.ledgerName
            guard !ledgerName.isEmpty else {
                errorMessage = JidalDataError.ledgerNotSelected.localizedDescription
                return
            }
            try transactionRepository.addTransaction(
                draft.makeTransaction(
                    id: NoteSerializer.makeTransactionID(),
                    by: categoryManager.authorName,
                    ledgerName: ledgerName
                ),
                in: group
            )
            selectedLedgerName = ledgerName
            groupRepository.persistSelectedLedger(ledgerName)
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTransaction(_ transaction: Transaction, with draft: TransactionDraft) async {
        guard let group = selectedGroup else { return }
        do {
            var updated = transaction
            updated.amount = draft.signedAmount
            updated.category = draft.category
            updated.memo = draft.memo
            updated.time = draft.time
            updated.date = draft.date
            updated.by = categoryManager.authorName
            updated.ledgerName = draft.ledgerName.isEmpty ? transaction.ledgerName : draft.ledgerName
            try transactionRepository.updateTransaction(original: transaction, updated: updated, in: group)
            selectedLedgerName = updated.ledgerName
            groupRepository.persistSelectedLedger(updated.ledgerName)
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTransaction(_ transaction: Transaction) async {
        guard let group = selectedGroup else { return }
        do {
            try transactionRepository.deleteTransaction(transaction, in: group)
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transactions(on date: Date) -> [Transaction] {
        monthTransactions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sortedByDateTimeDescending()
    }

    func transactionDatesInCurrentMonth() -> Set<Date> {
        Set(monthTransactions.map { Calendar.current.startOfDay(for: $0.date) })
    }

    func monthSummary() -> (income: Int, expense: Int) {
        let income = monthTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = monthTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        return (income, expense)
    }

    func categoryTotals() -> [(String, Int)] {
        let totals = Dictionary(grouping: monthTransactions.filter { $0.amount < 0 }, by: \.category)
            .map { ($0.key, $0.value.reduce(0) { $0 + abs($1.amount) }) }
            .sorted { $0.1 > $1.1 }
        return totals
    }

    func incomeCategoryTotals() -> [(String, Int)] {
        Dictionary(grouping: monthTransactions.filter { $0.amount > 0 }, by: \.category)
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
    }

    func expenseCategoryAmounts() -> [CategoryAmount] {
        categoryTotals().map { CategoryAmount(category: $0.0, amount: $0.1) }
    }

    func incomeCategoryAmounts() -> [CategoryAmount] {
        incomeCategoryTotals().map { CategoryAmount(category: $0.0, amount: $0.1) }
    }

    func rebuildSnapshots(startingFrom date: Date) async {
        guard let group = selectedGroup, let ledgerName = selectedLedgerName else { return }
        do {
            isBookClosingInProgress = true
            bookClosingProgressMonths = []
            bookClosingResultText = nil
            try snapshotRepository.rebuildSnapshots(ledgerName: ledgerName, in: group, startingFrom: date) { month in
                bookClosingProgressMonths.append(month.yearMonthDisplayText)
            }
            await reloadMainData()
            bookClosingResultText = "정리 완료! 잔액: \(currentBalance.signedWonString)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isBookClosingInProgress = false
    }

    func firstRecordDate() -> Date? {
        guard let group = selectedGroup else { return nil }
        return snapshotRepository.detectFirstRecordDate(in: group)
    }

    func deleteCurrentGroup() async {
        guard let group = selectedGroup else { return }
        do {
            try groupRepository.deleteGroup(group)
            selectedGroup = nil
            selectedLedgerName = nil
            widgetSyncManager.clear()
            await loadGroupsAndRoute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameCurrentGroup(to newName: String) async {
        guard let group = selectedGroup else { return }
        do {
            let renamed = try groupRepository.renameGroup(group, to: newName)
            selectedGroup = renamed
            availableGroups = groupRepository.fetchGroups()
            groupRepository.persistSelectedGroup(renamed.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeMonth(by offset: Int) async {
        currentMonth = currentMonth.addingMonth(offset).startOfMonth
        await reloadMainData()
    }

    func updateLedger(_ ledger: Ledger, name: String, icon: String, color: String) async {
        guard let group = selectedGroup else { return }
        do {
            try ledgerRepository.saveLedger(
                Ledger(name: name, icon: icon, color: color, currency: ledger.currency, sortOrder: ledger.sortOrder),
                in: group
            )
            if ledger.name != name {
                try ledgerRepository.deleteLedger(named: ledger.name, in: group)
                if selectedLedgerName == ledger.name {
                    selectedLedgerName = name
                    groupRepository.persistSelectedLedger(name)
                }
            }
            await reloadMainData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveLedgers(from source: IndexSet, to destination: Int) {
        ledgers.move(fromOffsets: source, toOffset: destination)
        guard let group = selectedGroup else { return }
        ledgerOrderManager.saveOrder(ledgers.map(\.name), for: group.id)
    }

    func refreshBudget() {
        guard let ledgerName = selectedLedgerName else {
            budgetProgress = []
            return
        }
        let budget = budgetManager.budget(for: ledgerName)
        var progressItems: [BudgetProgress] = []
        let expenseTotal = monthSummary().expense
        if budget.monthlyLimit > 0 {
            progressItems.append(BudgetProgress(title: "전체", spent: expenseTotal, limit: budget.monthlyLimit))
        }
        let totals = Dictionary(grouping: monthTransactions.filter { $0.amount < 0 }, by: \.category)
            .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
        for category in categoryManager.categories {
            if let limit = budget.categoryLimits[category], limit > 0 {
                progressItems.append(BudgetProgress(title: category, spent: totals[category, default: 0], limit: limit))
            }
        }
        budgetProgress = progressItems
    }

    var bookClosingEndMonthText: String {
        Date().addingMonth(-2).yearMonthDisplayText
    }

    func searchTransactions(query: String) -> [Transaction] {
        guard let group = selectedGroup, let ledgerName = selectedLedgerName else { return [] }
        return (try? transactionRepository.searchTransactions(query: query, ledgerName: ledgerName, group: group)) ?? []
    }

    private func buildMonthlyFlowData(ledgerName: String, group: JidalGroup) throws -> [MonthlyFlowData] {
        try stride(from: 5, through: 0, by: -1).map { offset in
            let monthDate = currentMonth.addingMonth(-offset).startOfMonth
            let transactions = try transactionRepository.fetchTransactions(inMonth: monthDate, ledgerName: ledgerName, group: group)
            let expense = transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
            let income = transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
            return MonthlyFlowData(month: monthDate.monthDisplayText, expense: expense, income: income)
        }
    }

    private func orderedLedgers(_ ledgers: [Ledger], for groupID: String) -> [Ledger] {
        let savedOrder = ledgerOrderManager.orderedNames(for: groupID)
        guard !savedOrder.isEmpty else { return ledgers }
        let orderMap = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })
        return ledgers.sorted {
            let left = orderMap[$0.name] ?? Int.max
            let right = orderMap[$1.name] ?? Int.max
            if left == right { return $0.sortOrder < $1.sortOrder }
            return left < right
        }
    }

    private func reloadAfterExternalChange() async {
        guard route == .main else { return }
        await reloadMainData()
    }

    private func syncWidgetData(group: JidalGroup, ledgerName: String) {
        let ledgerIcon = ledgers.first(where: { $0.name == ledgerName })?.icon ?? "wonsign.circle.fill"
        let liveBalance = (try? balanceCalculator.currentBalance(
            ledgerName: ledgerName,
            in: group,
            anchorDate: Date()
        )) ?? currentBalance
        widgetSyncManager.update(
            groupID: group.id,
            ledgerName: ledgerName,
            ledgerIcon: ledgerIcon,
            balance: liveBalance
        )
    }
}
