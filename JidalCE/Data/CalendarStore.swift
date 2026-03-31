import EventKit
import Foundation

final class CalendarStore {
    enum EventKind: String {
        case transaction
        case snapshot
        case history
        case meta
    }

    static let shared = CalendarStore()

    let eventStore = EKEventStore()
    private let scheme = "jidalce"

    private init() {}

    func requestAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToEvents()) ?? false
    }

    func jidalURL(for kind: EventKind, ledgerName: String) -> URL? {
        let encodedLedger = ledgerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ledgerName
        return URL(string: "\(scheme)://\(kind.rawValue)/\(encodedLedger)")
    }

    func isJidalEvent(_ event: EKEvent) -> Bool {
        event.url?.scheme == scheme
    }

    func isSystemEventTitle(_ title: String) -> Bool {
        title.hasPrefix("__snapshot_") || title.hasPrefix("__history_") || title.hasPrefix("__meta_")
    }

    func fetchEvents(from start: Date, to end: Date, calendar: EKCalendar) -> [EKEvent] {
        var results: [EKEvent] = []
        var chunkStart = start
        let maxSpan: TimeInterval = 3.5 * 365 * 24 * 60 * 60

        while chunkStart < end {
            let chunkEnd = min(chunkStart.addingTimeInterval(maxSpan), end)
            let predicate = eventStore.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: [calendar])
            results.append(contentsOf: eventStore.events(matching: predicate))
            chunkStart = chunkEnd
        }

        return results
    }

    func refreshedEvent(from event: EKEvent) -> EKEvent {
        guard let identifier = event.eventIdentifier,
              let refreshed = eventStore.event(withIdentifier: identifier) else {
            return event
        }
        return refreshed
    }
}
