import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CategoryManager {
    private let categoryKey = "defaultCategories"
    private let authorKey = "authorName"

    var categories: [String] = []
    var authorName: String = UIDevice.current.name

    init() {
        let defaults = UserDefaults.standard
        categories = defaults.stringArray(forKey: categoryKey) ?? [
            "식비", "교통", "생활", "문화", "의료", "교육", "의류", "미용", "통신", "보험", "급여", "용돈", "이자", "기타"
        ]
        authorName = defaults.string(forKey: authorKey) ?? UIDevice.current.name
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(trimmed) else { return }
        categories.append(trimmed)
        persist()
    }

    func removeCategories(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        persist()
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func updateAuthorName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        authorName = trimmed
        UserDefaults.standard.set(trimmed, forKey: authorKey)
    }

    private func persist() {
        UserDefaults.standard.set(categories, forKey: categoryKey)
    }
}
