import Charts
import SwiftUI

struct CategoryPieChart: View {
    let data: [CategoryAmount]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if data.isEmpty {
                Text("데이터가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("금액", item.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("카테고리", item.category))
                }
                .frame(height: 240)

                ForEach(data) { item in
                    HStack {
                        Text(item.category)
                        Spacer()
                        Text(item.amount.wonString)
                    }
                    Divider()
                }
            }
        }
    }
}
