import CoreGraphics
import Foundation

/// Listen-only global key-down tap. Counts presses; never reads which key was pressed.
final class KeyTap {
  private var tap: CFMachPort?
  private let onKeyDown: () -> Void

  init(onKeyDown: @escaping () -> Void) { self.onKeyDown = onKeyDown }

  var isRunning: Bool { tap != nil }

  /// Returns false when Input Monitoring has not been granted.
  func start() -> Bool {
    guard tap == nil else { return true }
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask,
        callback: { _, type, event, info in
          let me = Unmanaged<KeyTap>.fromOpaque(info!).takeUnretainedValue()
          switch type {
          case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
          case .keyDown where event.getIntegerValueField(.keyboardEventAutorepeat) == 0:
            me.onKeyDown()
          default:
            break
          }
          return Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque())
    else { return false }
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
    return true
  }
}
