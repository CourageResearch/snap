import Cocoa
import Carbon

// MARK: - Snap Position

enum SnapPosition {
    case none
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximized
}

// MARK: - Window Manager

class WindowManager {

    static let shared = WindowManager()

    private init() {}

    // Get the frontmost window
    func getFrontmostWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)

        if result == .success, let window = windowRef {
            return (window as! AXUIElement)
        }

        return nil
    }

    // Get current window frame
    func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        guard let positionRef = positionRef, let sizeRef = sizeRef else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }

    // Set window position and size
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var size = CGSize(width: frame.width, height: frame.height)

        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }

        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    // Get the screen frame for the current window
    func getCurrentScreen() -> NSScreen {
        if let window = getFrontmostWindow() {
            var positionRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)

            if let positionRef = positionRef {
                var position = CGPoint.zero
                AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)

                for screen in NSScreen.screens {
                    if screen.frame.contains(position) {
                        return screen
                    }
                }
            }
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    // Get usable screen frame (excluding menu bar and dock)
    func getUsableFrame() -> CGRect {
        let screen = getCurrentScreen()
        let visibleFrame = screen.visibleFrame
        let screenFrame = screen.frame

        let menuBarHeight = screenFrame.height - visibleFrame.height - visibleFrame.origin.y + screenFrame.origin.y

        return CGRect(
            x: visibleFrame.origin.x,
            y: menuBarHeight,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    // Detect current snap position
    func detectCurrentPosition() -> SnapPosition {
        guard let window = getFrontmostWindow(),
              let windowFrame = getWindowFrame(window) else {
            return .none
        }

        let screen = getUsableFrame()
        let tolerance: CGFloat = 20

        let isAtLeft = abs(windowFrame.origin.x - screen.origin.x) < tolerance
        let isAtRight = abs(windowFrame.origin.x + windowFrame.width - screen.origin.x - screen.width) < tolerance
        let isAtTop = abs(windowFrame.origin.y - screen.origin.y) < tolerance
        let isAtBottom = abs(windowFrame.origin.y + windowFrame.height - screen.origin.y - screen.height) < tolerance

        let isHalfWidth = abs(windowFrame.width - screen.width / 2) < tolerance
        let isFullWidth = abs(windowFrame.width - screen.width) < tolerance
        let isHalfHeight = abs(windowFrame.height - screen.height / 2) < tolerance
        let isFullHeight = abs(windowFrame.height - screen.height) < tolerance

        // Check quarters first
        if isHalfWidth && isHalfHeight {
            if isAtLeft && isAtTop { return .topLeft }
            if isAtRight && isAtTop { return .topRight }
            if isAtLeft && isAtBottom { return .bottomLeft }
            if isAtRight && isAtBottom { return .bottomRight }
        }

        // Check halves
        if isHalfWidth && isFullHeight {
            if isAtLeft { return .left }
            if isAtRight { return .right }
        }

        if isFullWidth && isHalfHeight {
            if isAtTop { return .top }
            if isAtBottom { return .bottom }
        }

        if isFullWidth && isFullHeight {
            return .maximized
        }

        return .none
    }

    // MARK: - Windows-style Smart Snap

    func handleLeft() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let current = detectCurrentPosition()

        switch current {
        case .right:
            // Right half -> Left half
            snapToFrame(window, frame: leftHalf(frame))
        case .topRight:
            // Top-right -> Top-left
            snapToFrame(window, frame: topLeft(frame))
        case .bottomRight:
            // Bottom-right -> Bottom-left
            snapToFrame(window, frame: bottomLeft(frame))
        case .left, .topLeft, .bottomLeft:
            // Already on left side, could move to previous monitor (not implemented)
            // For now, just snap to left half
            snapToFrame(window, frame: leftHalf(frame))
        default:
            // Any other state -> Left half
            snapToFrame(window, frame: leftHalf(frame))
        }
    }

    func handleRight() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let current = detectCurrentPosition()

        switch current {
        case .left:
            // Left half -> Right half
            snapToFrame(window, frame: rightHalf(frame))
        case .topLeft:
            // Top-left -> Top-right
            snapToFrame(window, frame: topRight(frame))
        case .bottomLeft:
            // Bottom-left -> Bottom-right
            snapToFrame(window, frame: bottomRight(frame))
        case .right, .topRight, .bottomRight:
            // Already on right side
            snapToFrame(window, frame: rightHalf(frame))
        default:
            // Any other state -> Right half
            snapToFrame(window, frame: rightHalf(frame))
        }
    }

    func handleUp() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let current = detectCurrentPosition()

        switch current {
        case .left:
            // Left half -> Top-left quarter
            snapToFrame(window, frame: topLeft(frame))
        case .right:
            // Right half -> Top-right quarter
            snapToFrame(window, frame: topRight(frame))
        case .bottomLeft:
            // Bottom-left -> Left half
            snapToFrame(window, frame: leftHalf(frame))
        case .bottomRight:
            // Bottom-right -> Right half
            snapToFrame(window, frame: rightHalf(frame))
        case .topLeft, .topRight:
            // Already at top, maximize
            snapToFrame(window, frame: frame)
        case .maximized:
            // Already maximized, do nothing or restore (not implemented)
            break
        default:
            // Any other state -> Maximize
            snapToFrame(window, frame: frame)
        }
    }

    func handleDown() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let current = detectCurrentPosition()

        switch current {
        case .left:
            // Left half -> Bottom-left quarter
            snapToFrame(window, frame: bottomLeft(frame))
        case .right:
            // Right half -> Bottom-right quarter
            snapToFrame(window, frame: bottomRight(frame))
        case .topLeft:
            // Top-left -> Left half
            snapToFrame(window, frame: leftHalf(frame))
        case .topRight:
            // Top-right -> Right half
            snapToFrame(window, frame: rightHalf(frame))
        case .bottomLeft, .bottomRight:
            // Already at bottom, minimize (not implemented) or do nothing
            break
        case .maximized:
            // Restore (not implemented) or do nothing
            break
        default:
            // Any other state -> do nothing or minimize
            break
        }
    }

    // MARK: - Frame Calculations

    func leftHalf(_ screen: CGRect) -> CGRect {
        return CGRect(x: screen.origin.x, y: screen.origin.y, width: screen.width / 2, height: screen.height)
    }

    func rightHalf(_ screen: CGRect) -> CGRect {
        return CGRect(x: screen.origin.x + screen.width / 2, y: screen.origin.y, width: screen.width / 2, height: screen.height)
    }

    func topLeft(_ screen: CGRect) -> CGRect {
        return CGRect(x: screen.origin.x, y: screen.origin.y, width: screen.width / 2, height: screen.height / 2)
    }

    func topRight(_ screen: CGRect) -> CGRect {
        return CGRect(x: screen.origin.x + screen.width / 2, y: screen.origin.y, width: screen.width / 2, height: screen.height / 2)
    }

    func bottomLeft(_ screen: CGRect) -> CGRect {
        return CGRect(x: screen.origin.x, y: screen.origin.y + screen.height / 2, width: screen.width / 2, height: screen.height / 2)
    }

    func bottomRight(_ screen: CGRect) -> CGRect {
        return CGRect(x: screen.origin.x + screen.width / 2, y: screen.origin.y + screen.height / 2, width: screen.width / 2, height: screen.height / 2)
    }

    func snapToFrame(_ window: AXUIElement, frame: CGRect) {
        setWindowFrame(window, frame: frame)
    }

    // MARK: - Direct Snap Methods (for menu)

    func snapLeft() { handleLeft() }
    func snapRight() { handleRight() }
    func snapUp() { handleUp() }
    func snapDown() { handleDown() }

    func snapMaximize() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        setWindowFrame(window, frame: frame)
    }

    func snapCenter() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let newFrame = CGRect(
            x: frame.origin.x + frame.width * 0.15,
            y: frame.origin.y + frame.height * 0.15,
            width: frame.width * 0.7,
            height: frame.height * 0.7
        )
        setWindowFrame(window, frame: newFrame)
    }

    // Thirds
    func snapLeftThird() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let newFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width / 3, height: frame.height)
        setWindowFrame(window, frame: newFrame)
    }

    func snapCenterThird() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let newFrame = CGRect(x: frame.origin.x + frame.width / 3, y: frame.origin.y, width: frame.width / 3, height: frame.height)
        setWindowFrame(window, frame: newFrame)
    }

    func snapRightThird() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let newFrame = CGRect(x: frame.origin.x + 2 * frame.width / 3, y: frame.origin.y, width: frame.width / 3, height: frame.height)
        setWindowFrame(window, frame: newFrame)
    }

    func snapLeftTwoThirds() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let newFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: 2 * frame.width / 3, height: frame.height)
        setWindowFrame(window, frame: newFrame)
    }

    func snapRightTwoThirds() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()
        let newFrame = CGRect(x: frame.origin.x + frame.width / 3, y: frame.origin.y, width: 2 * frame.width / 3, height: frame.height)
        setWindowFrame(window, frame: newFrame)
    }
}

// MARK: - Hotkey Manager

class HotkeyManager {

    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func start() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return HotkeyManager.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap. Make sure Accessibility permissions are granted.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown {
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            let hasControl = flags.contains(.maskControl)
            let hasOption = flags.contains(.maskAlternate)
            let hasCommand = flags.contains(.maskCommand)

            let wm = WindowManager.shared

            // Control + Option + Command for thirds
            if hasControl && hasOption && hasCommand {
                switch keyCode {
                case 18: // 1 - left third
                    wm.snapLeftThird()
                    return nil
                case 19: // 2 - center third
                    wm.snapCenterThird()
                    return nil
                case 20: // 3 - right third
                    wm.snapRightThird()
                    return nil
                case 21: // 4 - left two thirds
                    wm.snapLeftTwoThirds()
                    return nil
                case 23: // 5 - right two thirds
                    wm.snapRightTwoThirds()
                    return nil
                default:
                    break
                }
            }

            // Control + Option for Windows-style snapping
            if hasControl && hasOption && !hasCommand {
                switch keyCode {
                case 123: // Left arrow
                    wm.handleLeft()
                    return nil
                case 124: // Right arrow
                    wm.handleRight()
                    return nil
                case 126: // Up arrow
                    wm.handleUp()
                    return nil
                case 125: // Down arrow
                    wm.handleDown()
                    return nil
                case 36: // Return/Enter - maximize
                    wm.snapMaximize()
                    return nil
                case 8: // C - center
                    wm.snapCenter()
                    return nil
                default:
                    break
                }
            }
        }

        return Unmanaged.passRetained(event)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !checkAccessibilityPermissions() {
            showAccessibilityAlert()
        }

        setupStatusBar()
        HotkeyManager.shared.start()

        print("Snap is running! (Windows-style)")
        print("")
        print("Keyboard Shortcuts (Control + Option + Arrow):")
        print("  ← : Snap left (or move left if in quarter)")
        print("  → : Snap right (or move right if in quarter)")
        print("  ↑ : Quarter top (if half) or maximize")
        print("  ↓ : Quarter bottom (if half)")
        print("")
        print("  Enter: Maximize")
        print("  C: Center (70%)")
        print("")
        print("Thirds (Control + Option + Cmd + 1-5)")
    }

    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Snap needs accessibility permissions to manage windows.\n\nPlease go to System Settings > Privacy & Security > Accessibility and add Snap."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⊞"
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Snap Left (⌃⌥←)", action: #selector(snapLeft), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Right (⌃⌥→)", action: #selector(snapRight), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Up (⌃⌥↑)", action: #selector(snapUp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Down (⌃⌥↓)", action: #selector(snapDown), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Maximize (⌃⌥↩)", action: #selector(snapMaximize), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Center 70% (⌃⌥C)", action: #selector(snapCenter), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Left Third (⌃⌥⌘1)", action: #selector(snapLeftThird), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Center Third (⌃⌥⌘2)", action: #selector(snapCenterThird), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Right Third (⌃⌥⌘3)", action: #selector(snapRightThird), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Left 2/3 (⌃⌥⌘4)", action: #selector(snapLeftTwoThirds), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Right 2/3 (⌃⌥⌘5)", action: #selector(snapRightTwoThirds), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Snap", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func snapLeft() { WindowManager.shared.handleLeft() }
    @objc func snapRight() { WindowManager.shared.handleRight() }
    @objc func snapUp() { WindowManager.shared.handleUp() }
    @objc func snapDown() { WindowManager.shared.handleDown() }
    @objc func snapMaximize() { WindowManager.shared.snapMaximize() }
    @objc func snapCenter() { WindowManager.shared.snapCenter() }
    @objc func snapLeftThird() { WindowManager.shared.snapLeftThird() }
    @objc func snapCenterThird() { WindowManager.shared.snapCenterThird() }
    @objc func snapRightThird() { WindowManager.shared.snapRightThird() }
    @objc func snapLeftTwoThirds() { WindowManager.shared.snapLeftTwoThirds() }
    @objc func snapRightTwoThirds() { WindowManager.shared.snapRightTwoThirds() }

    @objc func quit() {
        HotkeyManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
