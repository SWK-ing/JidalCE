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
                    Color.black.opacity(0.08).ignoresSafeArea()
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
            .navigationTitle("지갑의달인 CE")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Picker("그룹", selection: Binding(
                get: { appState.selectedGroup?.id ?? "" },
                set: { newValue in
                    guard let group = appState.availableGroups.first(where: { $0.id == newValue }) else { return }
                    Task { await appState.selectExistingGroup(group) }
                }
            )) {
                ForEach(appState.availableGroups) { group in
                    Text(group.name).tag(group.id)
                }
            }
            .pickerStyle(.menu)

            Picker("가계부", selection: Binding(
                get: { appState.selectedLedgerName ?? "" },
                set: { appState.selectedLedgerName = $0; Task { await appState.reloadMainData() } }
            )) {
                ForEach(appState.ledgers) { ledger in
                    Text("\(ledger.icon) \(ledger.name)").tag(ledger.name)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
