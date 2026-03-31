struct Ledger: Identifiable, Hashable {
    var id: String { name }
    let name: String
    var icon: String
    var color: String
    var currency: String
    var sortOrder: Int
}
