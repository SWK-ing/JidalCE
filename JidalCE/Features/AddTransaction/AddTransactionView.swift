import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddTransactionViewModel

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.appState.ledgers.isEmpty {
                    Menu {
                        ForEach(viewModel.appState.ledgers) { ledger in
                            Button {
                                viewModel.draft.ledgerName = ledger.name
                            } label: {
                                LedgerLabelView(name: ledger.name, icon: ledger.icon)
                            }
                        }
                    } label: {
                        HStack {
                            Text("가계부")
                            Spacer()
                            if let selectedLedger = viewModel.appState.ledgers.first(where: { $0.name == viewModel.draft.ledgerName }) {
                                LedgerLabelView(name: selectedLedger.name, icon: selectedLedger.icon)
                            } else {
                                Text("선택")
                                    .foregroundStyle(.secondary)
                            }
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
    }
}
