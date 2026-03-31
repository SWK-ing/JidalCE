import Foundation

extension Int {
    var wonString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: self)) ?? "0")원"
    }

    var signedWonString: String {
        let sign = self >= 0 ? "+" : "-"
        return "\(sign)\(abs(self).wonString)"
    }

    var signedExpenseString: String {
        "-\(abs(self).wonString)"
    }

    var signedIncomeString: String {
        "+\(abs(self).wonString)"
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self }
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)?.endOfDay ?? self
    }
    var yearMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: self)
    }
    var yyyyMMddString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
    var hhmmString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    var monthDayHistoryString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/dd"
        return formatter.string(from: self)
    }
    var monthDisplayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월"
        return formatter.string(from: self)
    }
    var yearMonthDisplayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: self)
    }
    var koreanDisplayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: self)
    }

    func addingMonth(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    var calendarGridDays: [Date] {
        let month = startOfMonth
        let firstWeekday = Calendar.current.component(.weekday, from: month) - 1
        let gridStart = Calendar.current.date(byAdding: .day, value: -firstWeekday, to: month) ?? month
        return (0..<42).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

extension String {
    var firstDateFromYearMonth: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: self) else { return nil }
        return date.startOfMonth
    }

    var filteredDigits: String {
        filter(\.isNumber)
    }

    var filteredDigitsWithCommas: String {
        let digits = filteredDigits
        guard let value = Int(digits) else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? digits
    }
}

extension Array where Element == Transaction {
    func sortedByDateTimeDescending() -> [Transaction] {
        sorted {
            if $0.date != $1.date {
                return $0.date > $1.date
            }
            return $0.time > $1.time
        }
    }
}
