import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: CalendarTabViewModel
    @State private var activeSheet: ActiveSheet?
    @State private var showingVoiceInput = false
    @State private var showingSMSInput = false
    @State private var pendingParsedResult: AIService.ParsedResult?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                balanceCard
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    ForEach(viewModel.monthDays, id: \.self) { day in
                        dayCell(day)
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 12) {
                Button {
                    showingVoiceInput = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.orange, in: Circle())
                        .shadow(radius: 10, y: 6)
                }
                .disabled(!viewModel.appState.aiService.isConfigured)

                Button {
                    showingSMSInput = true
                } label: {
                    Image(systemName: "message.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.green, in: Circle())
                        .shadow(radius: 10, y: 6)
                }
                .disabled(!viewModel.appState.aiService.isConfigured)

                Button {
                    pendingParsedResult = nil
                    activeSheet = .add(UUID())
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue, in: Circle())
                        .shadow(radius: 10, y: 6)
                }
            }
            .padding()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                addTransactionView()
            case .detail(let date):
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(date.monthDayDisplayText)
                            .font(.headline)
                            .padding(.horizontal)
                        DayDetailView(
                            transactions: viewModel.appState.transactions(on: date),
                            onSelect: { transaction in
                                activeSheet = .edit(transaction)
                            }
                        )
                    }
                    .padding(.top)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            case .edit(let transaction):
                AddTransactionView(viewModel: AddTransactionViewModel(appState: viewModel.appState, editingTransaction: transaction))
            }
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView { result in
                pendingParsedResult = result
            }
            .environment(viewModel.appState)
        }
        .sheet(isPresented: $showingSMSInput) {
            SMSInputView { result in
                pendingParsedResult = result
            }
            .environment(viewModel.appState)
        }
        .onChange(of: showingVoiceInput) { _, isPresented in
            if !isPresented, pendingParsedResult != nil {
                activeSheet = .add(UUID())
            }
        }
        .onChange(of: showingSMSInput) { _, isPresented in
            if !isPresented, pendingParsedResult != nil {
                activeSheet = .add(UUID())
            }
        }
        .onChange(of: activeSheet?.id) { _, newValue in
            if newValue == nil {
                pendingParsedResult = nil
            }
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

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }
                if horizontal <= -50 {
                    Task { await viewModel.appState.changeMonth(by: 1) }
                } else if horizontal >= 50 {
                    Task { await viewModel.appState.changeMonth(by: -1) }
                }
            }
    }

    private var balanceCard: some View {
        let summary = viewModel.appState.monthSummary()
        let currency = selectedCurrencyCode
        let accent = selectedLedgerColor
        return VStack(alignment: .leading, spacing: 8) {
            Text("당월 잔액")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(fullSignedAmount(viewModel.appState.currentBalance, currency: currency))
                .font(.largeTitle.bold())
            HStack(spacing: 12) {
                Text("지출 \(fullSignedAmount(-summary.expense, currency: currency))")
                Text("수입 \(fullSignedAmount(summary.income, currency: currency))")
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [accent.opacity(0.9), accent.mix(with: .white, amount: 0.3).opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func addTransactionView() -> some View {
        let addViewModel = AddTransactionViewModel(appState: viewModel.appState)
        if let pendingParsedResult {
            let _ = addViewModel.applyParsedResult(pendingParsedResult)
        }
        AddTransactionView(viewModel: addViewModel)
    }

    private func dayCell(_ day: Date) -> some View {
        let isCurrentMonth = Calendar.current.isDate(day, equalTo: viewModel.appState.currentMonth, toGranularity: .month)
        let summary = daySummary(for: day)
        let currency = selectedCurrencyCode
        return Button {
            viewModel.selectedDate = day
            activeSheet = .detail(day)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCurrentMonth ? .primary : .secondary)

                if summary.income != 0 || summary.expense != 0 || summary.net != 0 {
                    VStack(alignment: .leading, spacing: 1) {
                        if summary.income > 0 {
                            Text(compactAmount(summary.income, currency: currency))
                                .foregroundStyle(isCurrentMonth ? .green : .green.opacity(0.5))
                        }
                        if summary.expense > 0 {
                            Text(compactAmount(summary.expense, currency: currency))
                                .foregroundStyle(isCurrentMonth ? .red : .red.opacity(0.5))
                        }
                        if summary.income > 0, summary.expense > 0 {
                            Text(compactSignedAmount(summary.net, currency: currency))
                                .foregroundStyle(netColor(for: summary.net, isCurrentMonth: isCurrentMonth))
                        }
                    }
                    .padding(.leading, 1)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
            .background(viewModel.selectedDate.startOfDay == day.startOfDay ? Color.blue.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func daySummary(for day: Date) -> (income: Int, expense: Int, net: Int) {
        let transactions = viewModel.appState.transactions(on: day)
        let income = transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        return (income, expense, income - expense)
    }

    private var selectedCurrencyCode: String {
        viewModel.appState.ledgers.first(where: { $0.name == viewModel.appState.selectedLedgerName })?.currency ?? "KRW"
    }

    private var selectedLedgerColor: Color {
        guard let rawColor = viewModel.appState.ledgers.first(where: { $0.name == viewModel.appState.selectedLedgerName })?.color else {
            return .accentColor
        }
        return ledgerColor(named: rawColor)
    }

    private func compactAmount(_ amount: Int, currency: String) -> String {
        guard amount != 0 else { return "0" }
        if currency == "KRW" {
            if amount >= 10_000 {
                return "\(amount / 10_000)만"
            }
            return "\(amount / 1_000)천"
        }
        return "\(currencySymbol(for: currency))\(compactNumber(amount))"
    }

    private func compactSignedAmount(_ amount: Int, currency: String) -> String {
        let prefix = amount >= 0 ? "+" : "-"
        let absolute = abs(amount)
        if absolute == 0 {
            return "0"
        }
        if currency == "KRW" {
            if absolute >= 10_000 {
                return "\(prefix)\(absolute / 10_000)만"
            }
            return "\(prefix)\(absolute / 1_000)천"
        }
        return "\(prefix)\(currencySymbol(for: currency))\(compactNumber(absolute))"
    }

    private func netColor(for amount: Int, isCurrentMonth: Bool) -> Color {
        let base: Color = amount >= 0 ? .green : .red
        return isCurrentMonth ? base : base.opacity(0.5)
    }

    private func fullSignedAmount(_ amount: Int, currency: String) -> String {
        let prefix = amount >= 0 ? "+" : "-"
        return prefix + fullAmount(abs(amount), currency: currency)
    }

    private func fullAmount(_ amount: Int, currency: String) -> String {
        if currency == "KRW" {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return "\(formatter.string(from: NSNumber(value: amount)) ?? "0")원"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(currencySymbol(for: currency))\(formatter.string(from: NSNumber(value: amount)) ?? "0")"
    }

    private func compactNumber(_ amount: Int) -> String {
        let value = Double(amount)
        let absValue = abs(value)
        switch absValue {
        case 1_000_000_000...:
            return String(format: "%.1fB", absValue / 1_000_000_000).replacingOccurrences(of: ".0", with: "")
        case 1_000_000...:
            return String(format: "%.1fM", absValue / 1_000_000).replacingOccurrences(of: ".0", with: "")
        case 1_000...:
            return String(format: "%.1fK", absValue / 1_000).replacingOccurrences(of: ".0", with: "")
        default:
            return String(Int(absValue))
        }
    }

    private func currencySymbol(for currency: String) -> String {
        switch currency {
        case "USD":
            return "$"
        case "JPY", "CNY":
            return "¥"
        case "EUR":
            return "€"
        case "IDR":
            return "Rp"
        case "PHP":
            return "₱"
        case "SGD":
            return "S$"
        case "VND":
            return "₫"
        case "THB":
            return "฿"
        default:
            return currency + " "
        }
    }

    private func ledgerColor(named name: String) -> Color {
        switch name {
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "green":
            return .green
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "pink":
            return .pink
        default:
            return .accentColor
        }
    }
}

private extension Color {
    func mix(with other: Color, amount: CGFloat) -> Color {
        let ratio = max(0, min(1, amount))
        let uiSelf = UIColor(self)
        let uiOther = UIColor(other)

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        uiSelf.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiOther.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return Color(
            red: Double(r1 + (r2 - r1) * ratio),
            green: Double(g1 + (g2 - g1) * ratio),
            blue: Double(b1 + (b2 - b1) * ratio),
            opacity: Double(a1 + (a2 - a1) * ratio)
        )
    }
}

private enum ActiveSheet: Identifiable {
    case add(UUID)
    case detail(Date)
    case edit(Transaction)

    var id: String {
        switch self {
        case .add(let id):
            return "add-\(id.uuidString)"
        case .detail(let date):
            return "detail-\(date.timeIntervalSinceReferenceDate)"
        case .edit(let transaction):
            return "edit-\(transaction.id)"
        }
    }
}
