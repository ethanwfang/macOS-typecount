// Checks for KeyCountCore. Run with `swift run KeyCountChecks`; exits non-zero on any failure.
import Foundation
import KeyCountCore

var failures = 0

func check<T: Equatable>(_ actual: T, _ expected: T, _ label: String, line: Int = #line) {
  if actual != expected {
    failures += 1
    print("FAIL line \(line) \(label): expected \(expected), got \(actual)")
  }
}

let utc: Calendar = {
  var c = Calendar(identifier: .gregorian)
  c.timeZone = TimeZone(identifier: "UTC")!
  return c
}()

let day = utc.date(from: DateComponents(year: 2026, month: 10, day: 13))!

func minute(day d: Int = 13, month: Int = 10, hour: Int, minute: Int = 0) -> Int {
  unixMinute(utc.date(from: DateComponents(year: 2026, month: month, day: d, hour: hour, minute: minute))!)
}

func tempStore() throws -> (Store, URL) {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("keycount-\(UUID()).sqlite")
  return (try Store(url: url), url)
}

do {
  let (store, url) = try tempStore()
  defer { try? FileManager.default.removeItem(at: url) }
  try store.add([100: 3, 101: 1])
  try store.add([100: 2])
  check(try store.summary(from: 100, to: 102), Summary(total: 6, peakKPM: 5, activeMinutes: 2), "accumulated summary")
  check(try store.summary(from: 101, to: 102).total, 1, "range is half-open")
  check(try store.firstMinute(), 100, "first minute")
}

do {
  let (store, url) = try tempStore()
  defer { try? FileManager.default.removeItem(at: url) }
  check(try PeriodStats(.allTime, now: day, store: store, calendar: utc).buckets.map(\.total), [0], "empty all time is this month")

  try store.add([
    minute(hour: 9): 120, minute(hour: 9, minute: 1): 30, minute(hour: 14, minute: 5): 50,  // today
    minute(day: 11, hour: 1): 10,  // Sunday, start of this week
    minute(day: 10, hour: 12): 7,  // Saturday, last week
    minute(day: 3, month: 9, hour: 8): 4,  // last month
  ])

  let today = try PeriodStats(.today, now: day, store: store, calendar: utc)
  check(today.summary, Summary(total: 200, peakKPM: 120, activeMinutes: 3), "today summary")
  check(today.summary.averageKPM, 66, "today average")
  check(today.buckets.count, 24, "today hours")
  check(today.buckets[9].total, 150, "9am")
  check(today.buckets[14].total, 50, "2pm")

  let week = try PeriodStats(.week, now: day, store: store, calendar: utc)
  check(week.buckets.map(\.total), [10, 0, 200, 0, 0, 0, 0], "week days")
  check(week.summary.total, 210, "week total")

  let month = try PeriodStats(.month, now: day, store: store, calendar: utc)
  check(month.buckets.count, 31, "october days")
  check(month.buckets[9].total, 7, "october 10")
  check(month.summary.total, 217, "month total")

  let all = try PeriodStats(.allTime, now: day, store: store, calendar: utc)
  check(all.buckets.map(\.total), [4, 217], "months since first record")
  check(all.summary, Summary(total: 221, peakKPM: 120, activeMinutes: 6), "all time summary")
}

print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
