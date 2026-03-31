import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: CalendarTabViewModel
    @State private var editingTransaction: Transaction?

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                balanceCard
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.monthDays, id: \.self) { day in
                        dayCell(day)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.selectedDate.koreanDisplayDate)
                        .font(.headline)
                    DayDetailView(
                        transactions: viewModel.appState.transactions(on: viewModel.selectedDate),
                        onSelect: { editingTransaction = $0 }
                    )
                }
            }
            .padding()
        }
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionView(viewModel: AddTransactionViewModel(appState: viewModel.appState, editingTransaction: transaction))
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                Task { await viewModel.appState.changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(viewModel.selectedMonthTitle)
                .font(.title3.bold())
            Spacer()
            Button {
                Task { await viewModel.appState.changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.bordered)
    }

    private var balanceCard: some View {
        let summary = viewModel.appState.monthSummary()
        return VStack(alignment: .leading, spacing: 8) {
            Text("당월 잔액")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.appState.currentBalance.signedWonString)
                .font(.largeTitle.bold())
            HStack(spacing: 12) {
                Text("지출 \(summary.expense.signedExpenseString)")
                Text("수입 \(summary.income.signedIncomeString)")
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(LinearGradient(colors: [.blue.opacity(0.85), .cyan.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
    }

    private func dayCell(_ day: Date) -> some View {
        let isCurrentMonth = Calendar.current.isDate(day, equalTo: viewModel.appState.currentMonth, toGranularity: .month)
        let hasTransactions = viewModel.appState.transactionDatesInCurrentMonth().contains(day.startOfDay)
        return Button {
            viewModel.selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .foregroundStyle(isCurrentMonth ? .primary : .secondary)
                Circle()
                    .fill(hasTransactions ? Color.white : Color.clear)
                    .frame(width: 6, height: 6)
                    .opacity(hasTransactions ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.vertical, 6)
            .background(viewModel.selectedDate.startOfDay == day.startOfDay ? Color.blue.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
