import SwiftUI

struct TransactionListView: View {
    @Bindable var viewModel: TransactionListViewModel
    @State private var editingTransaction: Transaction?
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        Task { await viewModel.appState.changeMonth(by: -1) }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(viewModel.appState.currentMonth.yearMonthDisplayText)
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await viewModel.appState.changeMonth(by: 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
            }

            if filteredTransactions.isEmpty {
                EmptyStateView(title: "거래 없음", message: "추가 버튼으로 첫 거래를 등록하세요.", systemImage: "won.sign")
                    .frame(height: 260)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(groupedTransactions(), id: \.date) { section in
                    Section(section.date.koreanDisplayDate) {
                        ForEach(section.transactions) { transaction in
                            Button {
                                editingTransaction = transaction
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(transaction.memo)
                                            .foregroundStyle(.primary)
                                        Text("\(transaction.time) · \(transaction.category) · \(transaction.by)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(transaction.amount.signedWonString)
                                        .foregroundStyle(transaction.amount > 0 ? .blue : .red)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.appState.deleteTransaction(transaction) }
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionView(viewModel: AddTransactionViewModel(appState: viewModel.appState, editingTransaction: transaction))
        }
        .searchable(text: $searchText, prompt: "거래 검색")
    }

    private func groupedTransactions() -> [(date: Date, transactions: [Transaction])] {
        Dictionary(grouping: filteredTransactions, by: { $0.date.startOfDay })
            .map { ($0.key, $0.value.sortedByDateTimeDescending()) }
            .sorted { $0.0 > $1.0 }
    }

    private var filteredTransactions: [Transaction] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.appState.monthTransactions
        }
        return viewModel.appState.monthTransactions.filter {
            $0.memo.localizedCaseInsensitiveContains(searchText)
        }
    }
}
