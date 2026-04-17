import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.route {
            case .calendarPermission:
                CalendarPermissionView()
            case .groupSetup:
                GroupSetupView()
            case .main:
                MainRootView()
            }
        }
        .task {
            await appState.bootstrap()
        }
        .alert("안내", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .overlay {
            if appState.isLoading {
                ZStack {
                    Color(.label).opacity(0.08).ignoresSafeArea()
                    ProgressView("불러오는 중...")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

private struct MainRootView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var showingAddLedgerSheet = false
    @State private var editingLedger: Ledger?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                TabView(selection: $selectedTab) {
                    CalendarTabView(viewModel: CalendarTabViewModel(appState: appState))
                        .tabItem { Label("달력", systemImage: "calendar") }
                        .tag(0)
                    TransactionListView(viewModel: TransactionListViewModel(appState: appState))
                        .tabItem { Label("목록", systemImage: "list.bullet.rectangle") }
                        .tag(1)
                    StatisticsView()
                        .tabItem { Label("통계", systemImage: "chart.bar.xaxis") }
                        .tag(2)
                    SettingsRootView()
                        .tabItem { Label("설정", systemImage: "gearshape") }
                        .tag(3)
                }
            }
        }
        .sheet(isPresented: $showingAddLedgerSheet) {
            QuickAddLedgerView()
                .environment(appState)
        }
        .sheet(item: $editingLedger) { ledger in
            LedgerEditView(ledger: ledger)
                .environment(appState)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(appState.availableGroups) { group in
                    Button(group.name) {
                        Task { await appState.selectExistingGroup(group) }
                    }
                }
            } label: {
                headerMenuLabel(
                    title: appState.selectedGroup?.name ?? "달력 선택"
                )
            }
            .frame(maxWidth: 110)

            Menu {
                ForEach(appState.ledgers) { ledger in
                    Button {
                        appState.selectedLedgerName = ledger.name
                        Task { await appState.reloadMainData() }
                    } label: {
                        LedgerLabelView(name: ledger.name, icon: ledger.icon)
                    }
                }
            } label: {
                headerLedgerMenuLabel(
                    ledger: appState.ledgers.first(where: { $0.name == appState.selectedLedgerName })
                )
            }
            .menuStyle(.button)
            .frame(maxWidth: .infinity)

            Button {
                editingLedger = appState.ledgers.first(where: { $0.name == appState.selectedLedgerName })
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(appState.selectedLedgerName == nil)

            Button {
                showingAddLedgerSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }

    private func headerMenuLabel(title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func headerLedgerMenuLabel(ledger: Ledger?) -> some View {
        HStack(spacing: 8) {
            if let ledger {
                LedgerLabelView(name: ledger.name, icon: ledger.icon)
                    .lineLimit(1)
            } else {
                Text("가계부 선택")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 4)
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuickAddLedgerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var icon = "wonsign.circle.fill"
    @State private var color = "blue"
    @State private var currency = "KRW"

    var body: some View {
        NavigationStack {
            Form {
                TextField("이름", text: $name)

                Section("아이콘") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(ledgerIcons, id: \.self) { ledgerIcon in
                            Button {
                                icon = ledgerIcon
                            } label: {
                                LedgerIconView(icon: ledgerIcon, color: icon == ledgerIcon ? .accentColor : .secondary)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(icon == ledgerIcon ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Picker("색상", selection: $color) {
                    ForEach(LedgerColor.allCases, id: \.rawValue) { preset in
                        Text(preset.rawValue).tag(preset.rawValue)
                    }
                }

                Picker("통화", selection: $currency) {
                    ForEach(supportedLedgerCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }
            .navigationTitle("새 가계부")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        Task {
                            await appState.addLedger(name: name, icon: icon, color: color, currency: currency)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
