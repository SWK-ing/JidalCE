import SwiftUI

struct TransactionSearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        List {
            if results.isEmpty {
                EmptyStateView(
                    title: "검색 결과 없음",
                    message: searchText.isEmpty ? "거래 메모를 검색해 보세요." : "최근 6개월 내 일치하는 거래가 없습니다.",
                    systemImage: "magnifyingglass"
                )
                .frame(height: 260)
                .listRowSeparator(.hidden)
            } else {
                ForEach(results) { transaction in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.memo)
                        Text("\(transaction.date.koreanDisplayDate) · \(transaction.category) · \(transaction.by)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(transaction.amount.signedWonString)
                            .foregroundStyle(transaction.amount > 0 ? .blue : .red)
                    }
                }
            }
        }
        .navigationTitle("거래 검색")
        .searchable(text: $searchText, prompt: "거래 검색")
    }

    private var results: [Transaction] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return appState.searchTransactions(query: searchText)
    }
}
