import SwiftUI

struct DayDetailView: View {
    let transactions: [Transaction]
    var onSelect: ((Transaction) -> Void)? = nil

    var body: some View {
        if transactions.isEmpty {
            EmptyStateView(title: "거래 없음", message: "선택한 날짜에 등록된 거래가 없습니다.", systemImage: "tray")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(transactions) { transaction in
                        Button {
                            onSelect?(transaction)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.memo)
                                    Text("\(transaction.category) · \(transaction.time) · \(transaction.by)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                Text(transaction.amount.signedWonString)
                                    .foregroundStyle(transaction.amount > 0 ? .blue : .red)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
