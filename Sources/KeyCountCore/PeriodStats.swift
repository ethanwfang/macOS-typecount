import Foundation

public struct Summary: Equatable {
  public var total = 0
  public var peakKPM = 0
  public var activeMinutes = 0

  public var averageKPM: Int { activeMinutes == 0 ? 0 : total / activeMinutes }

  public init(total: Int = 0, peakKPM: Int = 0, activeMinutes: Int = 0) {
    self.total = total
    self.peakKPM = peakKPM
    self.activeMinutes = activeMinutes
  }
}

public struct Bucket: Equatable {
  public var start: Date
  public var total: Int
}

public enum Period: String, CaseIterable {
  case today = "Today"
  case week = "Week"
  case month = "Month"
  case allTime = "All time"

  /// Chart bar size for this period.
  public var bucket: Calendar.Component {
    switch self {
    case .today: .hour
    case .week, .month: .day
    case .allTime: .month
    }
  }
}

public struct PeriodStats: Equatable {
  public var summary = Summary()
  public var buckets: [Bucket] = []

  public init() {}

  /// Calendar periods: today, this week, this month, or every month since the first recorded minute.
  public init(_ period: Period, now: Date, store: Store, calendar: Calendar = .current) throws {
    let range: DateInterval
    switch period {
    case .today: range = calendar.dateInterval(of: .day, for: now)!
    case .week: range = calendar.dateInterval(of: .weekOfYear, for: now)!
    case .month: range = calendar.dateInterval(of: .month, for: now)!
    case .allTime:
      let first = try store.firstMinute().map(date(ofMinute:)) ?? now
      range = DateInterval(
        start: calendar.dateInterval(of: .month, for: first)!.start, end: calendar.dateInterval(of: .month, for: now)!.end)
    }
    summary = try store.summary(from: unixMinute(range.start), to: unixMinute(range.end))

    var start = range.start
    while start < range.end {
      let next = calendar.date(byAdding: period.bucket, value: 1, to: start)!
      buckets.append(Bucket(start: start, total: try store.summary(from: unixMinute(start), to: unixMinute(next)).total))
      start = next
    }
  }
}

public func unixMinute(_ date: Date) -> Int { Int(date.timeIntervalSince1970 / 60) }

public func date(ofMinute minute: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(minute * 60)) }
