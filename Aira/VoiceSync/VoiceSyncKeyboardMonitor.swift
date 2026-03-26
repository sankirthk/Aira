import AppKit
import ApplicationServices

@MainActor
final class VoiceSyncKeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private var toggleShortcut: String = ""
    private var scrollUpShortcut: String = ""
    private var scrollDownShortcut: String = ""

    private var onToggle: (() -> Void)?
    private var onScrollUp: (() -> Void)?
    private var onScrollDown: (() -> Void)?

    func start(
        toggleShortcut: String,
        scrollUpShortcut: String,
        scrollDownShortcut: String,
        onToggle: @escaping () -> Void,
        onScrollUp: @escaping () -> Void,
        onScrollDown: @escaping () -> Void
    ) {
        stop()
        self.toggleShortcut = toggleShortcut
        self.scrollUpShortcut = scrollUpShortcut
        self.scrollDownShortcut = scrollDownShortcut
        self.onToggle = onToggle
        self.onScrollUp = onScrollUp
        self.onScrollDown = onScrollDown

        requestAccessibilityPermission()

        let mask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<VoiceSyncKeyboardMonitor>
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

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: userInfo
        ) else {
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
        onToggle = nil
        onScrollUp = nil
        onScrollDown = nil
        toggleShortcut = ""
        scrollUpShortcut = ""
        scrollDownShortcut = ""
    }

    private func handle(event: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        if !toggleShortcut.isEmpty, KeyboardShortcutDisplay.matches(event: nsEvent, shortcut: toggleShortcut) {
            onToggle?()
        } else if !scrollUpShortcut.isEmpty, KeyboardShortcutDisplay.matches(event: nsEvent, shortcut: scrollUpShortcut) {
            onScrollUp?()
        } else if !scrollDownShortcut.isEmpty, KeyboardShortcutDisplay.matches(event: nsEvent, shortcut: scrollDownShortcut) {
            onScrollDown?()
        }
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
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
        if !toggleShortcut.isEmpty, KeyboardShortcutDisplay.matches(event: event, shortcut: toggleShortcut) {
            onToggle?()
        } else if !scrollUpShortcut.isEmpty, KeyboardShortcutDisplay.matches(event: event, shortcut: scrollUpShortcut) {
            onScrollUp?()
        } else if !scrollDownShortcut.isEmpty, KeyboardShortcutDisplay.matches(event: event, shortcut: scrollDownShortcut) {
            onScrollDown?()
        }
    }
}
