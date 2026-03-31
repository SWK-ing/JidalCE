import Foundation

struct HistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let date: String
    let time: String
    let action: HistoryAction
    let memo: String
    let amount: String
    let by: String
}

enum HistoryAction: String, CaseIterable, Hashable {
    case added = "추가"
    case modified = "수정"
    case deleted = "삭제"
}
