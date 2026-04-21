import AppKit
import ApplicationServices

@MainActor
final class KeyboardShortcutMonitor {
  struct Binding {
    let shortcut: String
    let suppressAutoRepeat: Bool
    let action: () -> Void

    init(shortcut: String, suppressAutoRepeat: Bool = false, action: @escaping () -> Void) {
      self.shortcut = shortcut
      self.suppressAutoRepeat = suppressAutoRepeat
      self.action = action
    }
  }

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var localKeyMonitor: Any?
  private var globalKeyMonitor: Any?
  private var bindings: [Binding] = []

  func start(bindings: [Binding], promptForAccessibility: Bool = false) {
    stop()
    self.bindings = bindings.filter { !$0.shortcut.isEmpty }

    guard self.bindings.isEmpty == false else {
      return
    }

    // Prompt for Accessibility if not yet granted so the CGEventTap can be
    // created. During a session the app runs in .accessory mode, which means
    // NSEvent local/global monitors are unreliable — the CGEventTap is the
    // only mechanism that reliably captures keyboard events system-wide.
    guard Self.checkAccessibilityTrusted(prompt: promptForAccessibility) else {
      installEventMonitorFallback()
      return
    }

    let mask = (1 << CGEventType.keyDown.rawValue)
    let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else {
        return Unmanaged.passUnretained(event)
      }

      let monitor = Unmanaged<KeyboardShortcutMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let eventTap = monitor.eventTap {
          CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        return Unmanaged.passUnretained(event)
      }

      monitor.handle(event: event)
      return Unmanaged.passUnretained(event)
    }

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: CGEventMask(mask),
        callback: callback,
        userInfo: userInfo
      )
    else {
      installEventMonitorFallback()
      return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)

    self.eventTap = eventTap
    self.runLoopSource = source
  }

  func stop() {
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    if let eventTap = eventTap {
      CFMachPortInvalidate(eventTap)
    }
    if let localKeyMonitor {
      NSEvent.removeMonitor(localKeyMonitor)
    }
    if let globalKeyMonitor {
      NSEvent.removeMonitor(globalKeyMonitor)
    }
    runLoopSource = nil
    eventTap = nil
    localKeyMonitor = nil
    globalKeyMonitor = nil
    bindings = []
  }

  private func handle(event: CGEvent) {
    guard let nsEvent = NSEvent(cgEvent: event) else { return }
    handle(event: nsEvent)
  }

  /// Returns true if Accessibility is already granted. If not, shows the system
  /// prompt once so the user can grant it, then returns false. Callers should
  /// install the NSEvent fallback and retry tapCreate on the next start() call.
  @discardableResult
  static func checkAccessibilityTrusted(prompt: Bool) -> Bool {
    if AXIsProcessTrusted() { return true }
    guard prompt else {
      return false
    }
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
    return false
  }

  private func installEventMonitorFallback() {
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handle(event: event)
      return event
    }
    globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handle(event: event)
    }
  }

  private func handle(event: NSEvent) {
    for binding in bindings
    where KeyboardShortcutDisplay.matches(event: event, shortcut: binding.shortcut) {
      guard Self.shouldTriggerBinding(binding, isAutoRepeat: event.isARepeat) else {
        return
      }
      binding.action()
      return
    }
  }

  static func shouldTriggerBinding(_ binding: Binding, isAutoRepeat: Bool) -> Bool {
    !(binding.suppressAutoRepeat && isAutoRepeat)
  }
}

@MainActor
final class VoiceSyncKeyboardMonitor {
  private let monitor = KeyboardShortcutMonitor()

  func start(
    toggleShortcut: String,
    scrollUpShortcut: String,
    scrollDownShortcut: String,
    promptForAccessibility: Bool = false,
    onToggle: @escaping () -> Void,
    onScrollUp: @escaping () -> Void,
    onScrollDown: @escaping () -> Void
  ) {
    monitor.start(
      bindings: [
        .init(shortcut: toggleShortcut, suppressAutoRepeat: true, action: onToggle),
        .init(shortcut: scrollUpShortcut, action: onScrollUp),
        .init(shortcut: scrollDownShortcut, action: onScrollDown),
      ],
      promptForAccessibility: promptForAccessibility
    )
  }

  func stop() {
    monitor.stop()
  }
}
