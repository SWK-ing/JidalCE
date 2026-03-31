import Charts
import SwiftUI

struct StatisticsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            let summary = appState.monthSummary()
            VStack(spacing: 16) {
                header(summary: summary)

                HStack(spacing: 12) {
                    statCard(title: "수입", amount: summary.income, color: .blue)
                    statCard(title: "지출", amount: summary.expense, color: .red)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("월간 흐름")
                        .font(.headline)
                    MonthlyFlowChart(data: appState.recentMonthlyFlows)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                chartCard(title: "지출 카테고리", data: appState.expenseCategoryAmounts())
                chartCard(title: "수입 카테고리", data: appState.incomeCategoryAmounts())

                budgetCard
                .padding()
            }
            .padding()
        }
    }

    private func header(summary: (income: Int, expense: Int)) -> some View {
        HStack {
            Button {
                Task { await appState.changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack(spacing: 8) {
                Text(appState.currentMonth.yearMonthDisplayText)
                    .font(.title3.bold())
                Text("잔액 \(appState.currentBalance.signedWonString)")
                    .font(.headline)
                Text("지출 \(summary.expense.wonString) · 수입 \(summary.income.wonString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await appState.changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private func chartCard(title: String, data: [CategoryAmount]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CategoryPieChart(data: data, title: title)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("예산")
                .font(.headline)
            if appState.budgetProgress.isEmpty {
                Text("설정 탭에서 예산을 설정하세요.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.budgetProgress, id: \.title) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title)
                            Spacer()
                            Text("\(item.spent.wonString) / \(item.limit.wonString)")
                            if item.statusText == "주의" {
                                Text("⚠️")
                            } else if item.statusText == "초과" {
                                Text("🔴")
                            }
                        }
                        ProgressView(value: item.ratio)
                            .tint(item.statusText == "초과" ? .red : item.statusText == "주의" ? .orange : .blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func statCard(title: String, amount: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(amount == 0 ? "0원" : amount.wonString)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }
}
