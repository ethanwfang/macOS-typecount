import Foundation
import SQLite3

/// Persists keystroke counts in per-minute buckets keyed by Unix minute.
public final class Store {
  public enum Failure: Error { case sqlite(String) }

  private var db: OpaquePointer?

  public init(url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw Failure.sqlite(message) }
    try exec("CREATE TABLE IF NOT EXISTS minutes (minute INTEGER PRIMARY KEY, count INTEGER NOT NULL)")
  }

  deinit { sqlite3_close(db) }

  public func add(_ counts: [Int: Int]) throws {
    guard !counts.isEmpty else { return }
    try exec("BEGIN")
    let stmt = try prepare(
      "INSERT INTO minutes (minute, count) VALUES (?, ?) ON CONFLICT(minute) DO UPDATE SET count = count + excluded.count")
    defer { sqlite3_finalize(stmt) }
    for (minute, count) in counts {
      sqlite3_bind_int64(stmt, 1, Int64(minute))
      sqlite3_bind_int64(stmt, 2, Int64(count))
      guard sqlite3_step(stmt) == SQLITE_DONE else {
        try? exec("ROLLBACK")
        throw Failure.sqlite(message)
      }
      sqlite3_reset(stmt)
    }
    try exec("COMMIT")
  }

  /// Aggregates buckets with `from <= minute < to`.
  public func summary(from: Int, to: Int) throws -> Summary {
    let stmt = try prepare(
      "SELECT COALESCE(SUM(count), 0), COALESCE(MAX(count), 0), COUNT(*) FROM minutes WHERE minute >= ? AND minute < ? AND count > 0")
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int64(stmt, 1, Int64(from))
    sqlite3_bind_int64(stmt, 2, Int64(to))
    guard sqlite3_step(stmt) == SQLITE_ROW else { throw Failure.sqlite(message) }
    return Summary(
      total: Int(sqlite3_column_int64(stmt, 0)), peakKPM: Int(sqlite3_column_int64(stmt, 1)),
      activeMinutes: Int(sqlite3_column_int64(stmt, 2)))
  }

  public func firstMinute() throws -> Int? {
    let stmt = try prepare("SELECT MIN(minute) FROM minutes")
    defer { sqlite3_finalize(stmt) }
    guard sqlite3_step(stmt) == SQLITE_ROW else { throw Failure.sqlite(message) }
    return sqlite3_column_type(stmt, 0) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 0))
  }

  private var message: String { String(cString: sqlite3_errmsg(db)) }

  private func exec(_ sql: String) throws {
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw Failure.sqlite(message) }
  }

  private func prepare(_ sql: String) throws -> OpaquePointer? {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw Failure.sqlite(message) }
    return stmt
  }
}
