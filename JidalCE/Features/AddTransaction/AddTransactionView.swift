import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddTransactionViewModel
    @State private var showingVoiceInput = false
    @State private var showingSMSInput = false

    var body: some View {
        NavigationStack {
            Form {
                Section("입력 방법") {
                    HStack {
                        Button("🎙 음성") {
                            showingVoiceInput = true
                        }
                        .disabled(!viewModel.appState.aiService.isConfigured)

                        Button("💬 SMS") {
                            showingSMSInput = true
                        }
                        .disabled(!viewModel.appState.aiService.isConfigured)
                    }
                }

                if !viewModel.appState.ledgers.isEmpty {
                    Picker("가계부", selection: $viewModel.draft.ledgerName) {
                        ForEach(viewModel.appState.ledgers) { ledger in
                            Text("\(ledger.icon) \(ledger.name)").tag(ledger.name)
                        }
                    }
                }

                Picker("유형", selection: $viewModel.draft.isIncome) {
                    Text("지출").tag(false)
                    Text("수입").tag(true)
                }
                .pickerStyle(.segmented)

                TextField("금액", text: $viewModel.draft.amountText)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.draft.amountText) { _, newValue in
                        viewModel.draft.amountText = newValue.filteredDigitsWithCommas
                    }

                Picker("카테고리", selection: $viewModel.draft.category) {
                    ForEach(viewModel.appState.categoryManager.categories, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                TextField("메모", text: $viewModel.draft.memo)
                DatePicker("날짜", selection: $viewModel.draft.date, displayedComponents: .date)
                TextField("시간", text: $viewModel.draft.time)
            }
            .navigationTitle(viewModel.titleText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.draft.memo.isEmpty || viewModel.draft.amountText.isEmpty || viewModel.draft.ledgerName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView { result in
                viewModel.applyParsedResult(result)
            }
        }
        .sheet(isPresented: $showingSMSInput) {
            SMSInputView { result in
                viewModel.applyParsedResult(result)
            }
        }
    }
}
