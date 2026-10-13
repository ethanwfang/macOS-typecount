import Charts
import KeyCountCore
import SwiftUI

struct PopoverView: View {
  @ObservedObject var tracker: Tracker

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      switch tracker.access {
      case .granted: EmptyView()
      case .needsGrant: accessBanner("KeyCount needs Input Monitoring to count keystrokes.", button: "Open Settings", action: tracker.requestAccess)
      case .needsRestart: accessBanner("Access granted. Restart KeyCount to start counting.", button: "Restart", action: tracker.relaunch)
      }

      Picker("Period", selection: $tracker.period) {
        ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      VStack(alignment: .leading, spacing: 2) {
        Text("Keystrokes").font(.subheadline).foregroundStyle(.secondary)
        Text(summary.total.formatted()).font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
      }

      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
        GridRow {
          stat("Now", "\(tracker.currentKPM)", unit: "kpm", wpmFrom: tracker.currentKPM)
          stat("Peak", "\(summary.peakKPM)", unit: "kpm", wpmFrom: summary.peakKPM)
        }
        GridRow {
          stat("Average", "\(summary.averageKPM)", unit: "kpm", wpmFrom: summary.averageKPM)
          stat("Active", activeTime, unit: nil)
        }
      }

      section(chartTitle) {
        Chart(tracker.stats.buckets, id: \.start) { bucket in
          BarMark(x: .value("Time", bucket.start, unit: tracker.period.bucket), y: .value("Keys", bucket.total))
            .foregroundStyle(Color.accentColor)
        }
        .chartXAxis { xAxis }
        .chartYAxis { AxisMarks(position: .leading) { AxisValueLabel() } }
        .frame(height: 100)
      }

      Divider()
      HStack {
        Toggle("Launch at login", isOn: $tracker.launchAtLogin).toggleStyle(.checkbox)
        Spacer()
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
      }
      .font(.callout)
    }
    .padding(16)
    .frame(width: 300)
    .onAppear { tracker.isViewing = true }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in tracker.isViewing = true }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in tracker.isViewing = false }
  }

  private var summary: Summary { tracker.stats.summary }

  private var chartTitle: String {
    switch tracker.period {
    case .today: "By hour"
    case .week, .month: "By day"
    case .allTime: "By month"
    }
  }

  @AxisContentBuilder private var xAxis: some AxisContent {
    switch tracker.period {
    case .today: AxisMarks(values: .stride(by: .hour, count: 6)) { AxisValueLabel(format: .dateTime.hour()) }
    case .week: AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)) }
    case .month: AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day()) }
    case .allTime: AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.narrow)) }
    }
  }

  private var activeTime: String {
    let m = summary.activeMinutes
    return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
  }

  /// Typing-test convention: one word is five keystrokes.
  private func stat(_ title: String, _ value: String, unit: String?, wpmFrom kpm: Int? = nil) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value).font(.title3.weight(.medium)).monospacedDigit()
        if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
      }
      if let kpm { Text("≈ \(kpm / 5) wpm").font(.caption).foregroundStyle(.secondary).monospacedDigit() }
    }
  }

  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      content()
    }
  }

  private func accessBanner(_ text: String, button: String, action: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(text).font(.callout)
      Button(button, action: action).buttonStyle(.borderedProminent)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
  }
}
