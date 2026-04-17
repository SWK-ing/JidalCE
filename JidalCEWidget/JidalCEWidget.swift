import EventKit
import SwiftUI
import WidgetKit

struct JidalCEEntry: TimelineEntry {
    let date: Date
    let ledgerName: String
    let ledgerIcon: String
    let todayExpense: Int
    let todayIncome: Int
    let monthExpense: Int
    let monthIncome: Int
    let balance: Int
    let topCategories: [(String, Int)]
}

struct JidalCEWidgetProvider: TimelineProvider {
    private let store = EKEventStore()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.JidalCE.app")

    func placeholder(in context: Context) -> JidalCEEntry {
        sampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (JidalCEEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JidalCEEntry>) -> Void) {
        let entry = buildEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func buildEntry() -> JidalCEEntry {
        let calendarID = sharedDefaults?.string(forKey: "widgetCalendarId") ?? ""
        let ledgerName = sharedDefaults?.string(forKey: "widgetLedgerName") ?? "생활비"
        let ledgerIcon = migratedLedgerIconName(sharedDefaults?.string(forKey: "widgetLedgerIcon") ?? "wonsign.circle.fill")
        let cachedBalance = sharedDefaults?.integer(forKey: "widgetBalance") ?? 0

        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            return JidalCEEntry(
                date: Date(),
                ledgerName: ledgerName,
                ledgerIcon: ledgerIcon,
                todayExpense: 0,
                todayIncome: 0,
                monthExpense: 0,
                monthIncome: 0,
                balance: cachedBalance,
                topCategories: []
            )
        }

        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? now
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: monthStart) ?? now

        let todayTransactions = transactions(
            from: dayStart,
            to: dayEnd,
            ledgerName: ledgerName,
            calendar: calendar
        )
        let monthTransactions = transactions(
            from: monthStart,
            to: monthEnd,
            ledgerName: ledgerName,
            calendar: calendar
        )

        let todayExpense = todayTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let todayIncome = todayTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let monthExpense = monthTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let monthIncome = monthTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let topCategories = Dictionary(grouping: monthTransactions.filter { $0.amount < 0 }, by: \.category)
            .map { ($0.key, $0.value.reduce(0) { $0 + abs($1.amount) }) }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }

        return JidalCEEntry(
            date: now,
            ledgerName: ledgerName,
            ledgerIcon: ledgerIcon,
            todayExpense: todayExpense,
            todayIncome: todayIncome,
            monthExpense: monthExpense,
            monthIncome: monthIncome,
            balance: cachedBalance,
            topCategories: topCategories
        )
    }

    private func transactions(from start: Date, to end: Date, ledgerName: String, calendar: EKCalendar) -> [TransactionRecord] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        return store.events(matching: predicate)
            .filter {
                $0.title == ledgerName &&
                !$0.title.isEmpty &&
                !isSystemEventTitle($0.title) &&
                $0.url?.scheme == "jidalce"
            }
            .flatMap { event in
                (try? NoteSerializer.parse(event.notes)) ?? []
            }
    }

    private func isSystemEventTitle(_ title: String) -> Bool {
        title.hasPrefix("__snapshot_") || title.hasPrefix("__history_") || title.hasPrefix("__meta_")
    }

    private var sampleEntry: JidalCEEntry {
        JidalCEEntry(
            date: Date(),
            ledgerName: "생활비",
            ledgerIcon: "wonsign.circle.fill",
            todayExpense: 45500,
            todayIncome: 0,
            monthExpense: 350000,
            monthIncome: 5000000,
            balance: 2500000,
            topCategories: [("식비", 120000), ("교통", 84000), ("생활", 76000)]
        )
    }
}

struct JidalCESmallWidget: Widget {
    let kind = "JidalCESmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JidalCEWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 지출")
        .description("오늘 지출 금액과 잔액을 표시합니다")
        .supportedFamilies([.systemSmall])
    }
}

struct JidalCEMediumWidget: Widget {
    let kind = "JidalCEMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JidalCEWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("월간 요약")
        .description("이번 달 지출, 수입, 잔액과 카테고리 현황을 표시합니다")
        .supportedFamilies([.systemMedium])
    }
}

private struct SmallWidgetView: View {
    let entry: JidalCEEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: migratedLedgerIconName(entry.ledgerIcon))
                Text(entry.ledgerName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            Spacer()

            Text("오늘 지출")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amountText(entry.todayExpense, forceMinus: true))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Text("잔액")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amountText(entry.balance))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct MediumWidgetView: View {
    let entry: JidalCEEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: migratedLedgerIconName(entry.ledgerIcon))
                    Text(entry.ledgerName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Text(monthText(from: entry.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                LabeledAmount(label: "지출", amount: entry.monthExpense, color: .red, forceMinus: true)
                LabeledAmount(label: "수입", amount: entry.monthIncome, color: .blue)
                LabeledAmount(label: "잔액", amount: entry.balance, color: .primary)
            }

            if !entry.topCategories.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("카테고리")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(entry.topCategories, id: \.0) { category, amount in
                        HStack(spacing: 6) {
                            Text(category)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(amountText(amount, forceMinus: true))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct LabeledAmount: View {
    let label: String
    let amount: Int
    let color: Color
    var forceMinus = false

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(amountText(amount, forceMinus: forceMinus))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private func amountText(_ amount: Int, forceMinus: Bool = false) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let value = abs(amount)
    let number = formatter.string(from: NSNumber(value: value)) ?? "0"
    if forceMinus {
        return "-\(number)원"
    }
    if amount < 0 {
        return "-\(number)원"
    }
    return "\(number)원"
}

private func monthText(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월"
    return formatter.string(from: date)
}

private func migratedLedgerIconName(_ icon: String) -> String {
    let legacyLedgerIconMap = [
        "💰": "wonsign.circle.fill",
        "🏠": "house.fill",
        "✈️": "airplane",
        "🚗": "car.fill",
        "🎓": "graduationcap.fill",
        "💊": "cross.case.fill",
        "🛒": "cart.fill",
        "👶": "figure.and.child.holdinghands",
        "🐶": "pawprint.fill",
        "🎮": "gamecontroller.fill",
        "📱": "iphone",
        "💳": "creditcard.fill"
    ]
    return legacyLedgerIconMap[icon] ?? icon
}

#Preview("Small", as: .systemSmall) {
    JidalCESmallWidget()
} timeline: {
    JidalCEEntry(
        date: .now,
        ledgerName: "생활비",
        ledgerIcon: "wonsign.circle.fill",
        todayExpense: 45500,
        todayIncome: 0,
        monthExpense: 350000,
        monthIncome: 5000000,
        balance: 2500000,
        topCategories: [("식비", 120000), ("교통", 84000), ("생활", 76000)]
    )
}

#Preview("Medium", as: .systemMedium) {
    JidalCEMediumWidget()
} timeline: {
    JidalCEEntry(
        date: .now,
        ledgerName: "생활비",
        ledgerIcon: "wonsign.circle.fill",
        todayExpense: 45500,
        todayIncome: 0,
        monthExpense: 350000,
        monthIncome: 5000000,
        balance: 2500000,
        topCategories: [("식비", 120000), ("교통", 84000), ("생활", 76000)]
    )
}
