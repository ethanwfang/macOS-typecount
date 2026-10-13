import AppKit
import CoreGraphics
import KeyCountCore
import ServiceManagement

@MainActor
final class Tracker: ObservableObject {
  enum Access { case granted, needsGrant, needsRestart }

  @Published private(set) var todayTotal = 0
  @Published private(set) var currentKPM = 0
  @Published private(set) var stats = PeriodStats()
  @Published var period = Period.today {
    didSet { refreshStats() }
  }
  /// Stats only refresh while the popover is on screen.
  var isViewing = false {
    didSet { if isViewing { refreshStats() } }
  }
  @Published private(set) var access = Access.needsGrant
  @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
    didSet { setLaunchAtLogin(launchAtLogin) }
  }

  private let store: Store
  private let calendar = Calendar.current
  private var tap: KeyTap!
  private var dayStart: Date
  private var unsaved: [Int: Int] = [:]
  private var recent: [Date] = []
  private var ticks = 0

  init() {
    let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("KeyCount/keycount.sqlite")
    store = try! Store(url: url)
    dayStart = calendar.startOfDay(for: Date())
    tap = KeyTap { [unowned self] in MainActor.assumeIsolated { self.record() } }
    loadTodayTotal()
    connectTap()
    enableLaunchAtLoginOnFirstRun()

    NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) {
      [unowned self] _ in MainActor.assumeIsolated { self.flush() }
    }
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned self] _ in
      MainActor.assumeIsolated { self.tick() }
    }
  }

  func requestAccess() {
    CGRequestListenEventAccess()
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
  }

  /// macOS sometimes only honours a fresh Input Monitoring grant after a relaunch.
  func relaunch() {
    flush()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", "sleep 1; open \"$0\"", Bundle.main.bundlePath]
    try? task.run()
    NSApp.terminate(nil)
  }

  private func record() {
    let now = Date()
    todayTotal += 1
    unsaved[unixMinute(now), default: 0] += 1
    recent.append(now)
  }

  private func tick() {
    let now = Date()
    if calendar.startOfDay(for: now) != dayStart {
      flush()
      dayStart = calendar.startOfDay(for: now)
      loadTodayTotal()
    }
    if !tap.isRunning { connectTap() }
    recent.removeAll { now.timeIntervalSince($0) >= 60 }
    currentKPM = recent.count
    ticks += 1
    if isViewing {
      refreshStats()
    } else if ticks % 10 == 0 {
      flush()
    }
  }

  private func flush() {
    do {
      try store.add(unsaved)
      unsaved = [:]
    } catch {
      NSLog("KeyCount: failed to save counts: \(error)")
    }
  }

  private func loadTodayTotal() {
    let end = calendar.date(byAdding: .day, value: 1, to: dayStart)!
    todayTotal = (try? store.summary(from: unixMinute(dayStart), to: unixMinute(end)).total) ?? 0
  }

  /// Flushes first so the stored aggregates include keys pressed since the last save.
  private func refreshStats() {
    flush()
    do {
      stats = try PeriodStats(period, now: Date(), store: store, calendar: calendar)
    } catch {
      NSLog("KeyCount: failed to load stats: \(error)")
    }
  }

  private func connectTap() {
    if tap.start() {
      access = .granted
    } else {
      access = CGPreflightListenEventAccess() ? .needsRestart : .needsGrant
    }
  }

  private func enableLaunchAtLoginOnFirstRun() {
    let key = "didConfigureLaunchAtLogin"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    UserDefaults.standard.set(true, forKey: key)
    launchAtLogin = true
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      NSLog("KeyCount: launch at login change failed: \(error)")
    }
  }
}
