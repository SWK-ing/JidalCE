import Charts
import SwiftUI

struct MonthlyFlowChart: View {
    let data: [MonthlyFlowData]

    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("월", item.month),
                y: .value("지출", item.expense)
            )
            .foregroundStyle(.red.opacity(0.8))

            BarMark(
                x: .value("월", item.month),
                y: .value("수입", item.income)
            )
            .foregroundStyle(.blue.opacity(0.75))
        }
        .frame(height: 220)
    }
}
