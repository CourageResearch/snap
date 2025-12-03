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

// MARK: - Preferences

class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var showMenuBarIcon: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showMenuBarIcon") }
    }

    private init() {}
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
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

            if let positionRef = positionRef, let sizeRef = sizeRef {
                var position = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

                // Use the center of the window for better detection
                let windowCenter = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)

                // Find which screen contains the window center
                for screen in NSScreen.screens {
                    // Convert screen frame to the same coordinate system as AX (origin at top-left of main screen)
                    let mainScreen = NSScreen.screens[0]
                    let screenTop = mainScreen.frame.height - screen.frame.origin.y - screen.frame.height
                    let screenRect = CGRect(x: screen.frame.origin.x, y: screenTop, width: screen.frame.width, height: screen.frame.height)

                    if screenRect.contains(windowCenter) {
                        return screen
                    }
                }

                // Fallback: find screen by X position overlap
                for screen in NSScreen.screens {
                    if position.x >= screen.frame.origin.x && position.x < screen.frame.origin.x + screen.frame.width {
                        return screen
                    }
                }
            }
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - Diagnostics

    func showDiagnostics() {
        var info = "=== SNAP DIAGNOSTICS ===\n\n"

        // Screen info
        info += "SCREENS (\(NSScreen.screens.count) total):\n"
        let mainScreen = NSScreen.screens[0]
        info += "Main screen height: \(mainScreen.frame.height)\n\n"

        for (i, screen) in NSScreen.screens.enumerated() {
            info += "Screen \(i): \(screen.localizedName)\n"
            info += "  frame: x=\(screen.frame.origin.x), y=\(screen.frame.origin.y), w=\(screen.frame.width), h=\(screen.frame.height)\n"
            info += "  visibleFrame: x=\(screen.visibleFrame.origin.x), y=\(screen.visibleFrame.origin.y), w=\(screen.visibleFrame.width), h=\(screen.visibleFrame.height)\n"

            // Convert to AX coordinates
            let screenTop = mainScreen.frame.height - screen.frame.origin.y - screen.frame.height
            info += "  AX coords: x=\(screen.frame.origin.x), y=\(screenTop), w=\(screen.frame.width), h=\(screen.frame.height)\n\n"
        }

        // Window info
        if let window = getFrontmostWindow() {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

            if let positionRef = positionRef, let sizeRef = sizeRef {
                var position = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

                info += "FRONTMOST WINDOW:\n"
                info += "  AX position: x=\(position.x), y=\(position.y)\n"
                info += "  AX size: w=\(size.width), h=\(size.height)\n"

                let windowCenter = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
                info += "  Window center: x=\(windowCenter.x), y=\(windowCenter.y)\n\n"

                // Check which screen contains it
                info += "SCREEN DETECTION:\n"
                for (i, screen) in NSScreen.screens.enumerated() {
                    let screenTop = mainScreen.frame.height - screen.frame.origin.y - screen.frame.height
                    let screenRect = CGRect(x: screen.frame.origin.x, y: screenTop, width: screen.frame.width, height: screen.frame.height)
                    let contains = screenRect.contains(windowCenter)
                    info += "  Screen \(i) AX rect: x=\(screenRect.origin.x), y=\(screenRect.origin.y), w=\(screenRect.width), h=\(screenRect.height) -> contains center: \(contains)\n"
                }

                let detected = getCurrentScreen()
                info += "\n  Detected screen: \(detected.localizedName)\n"
            }
        } else {
            info += "NO FRONTMOST WINDOW FOUND\n"
        }

        // Show alert with info
        let alert = NSAlert()
        alert.messageText = "Snap Diagnostics"
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(info, forType: .string)
        }
    }

    // MARK: - Multi-Monitor Support

    func getNextScreen(direction: Int) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }

        let currentScreen = getCurrentScreen()

        // Sort screens by x position for left/right navigation
        let sortedScreens = screens.sorted { $0.frame.origin.x < $1.frame.origin.x }

        // Find current screen by comparing frames (more reliable than direct comparison)
        var currentIndex: Int? = nil
        for (index, screen) in sortedScreens.enumerated() {
            if screen.frame.origin.x == currentScreen.frame.origin.x &&
               screen.frame.origin.y == currentScreen.frame.origin.y {
                currentIndex = index
                break
            }
        }

        guard let idx = currentIndex else { return nil }

        let newIndex = idx + direction
        if newIndex >= 0 && newIndex < sortedScreens.count {
            return sortedScreens[newIndex]
        }

        return nil
    }

    func getUsableFrame(for screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let mainScreen = NSScreen.screens[0]

        // Convert from macOS coordinates (origin bottom-left) to AX coordinates (origin top-left of main screen)
        // In macOS: y=0 is at bottom, y increases upward
        // In AX: y=0 is at top of main screen, y increases downward

        // The top of the visible frame in AX coordinates
        let visibleTop = mainScreen.frame.height - (visibleFrame.origin.y + visibleFrame.height)

        return CGRect(
            x: visibleFrame.origin.x,
            y: visibleTop,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    // Get usable screen frame (excluding menu bar and dock)
    func getUsableFrame() -> CGRect {
        return getUsableFrame(for: getCurrentScreen())
    }

    // Detect current snap position
    func detectCurrentPosition() -> SnapPosition {
        guard let window = getFrontmostWindow(),
              let windowFrame = getWindowFrame(window) else {
            return .none
        }

        let screen = getUsableFrame()
        let tolerance: CGFloat = 50

        let isAtLeft = abs(windowFrame.origin.x - screen.origin.x) < tolerance
        let isAtRight = abs(windowFrame.origin.x + windowFrame.width - screen.origin.x - screen.width) < tolerance
        let isAtTop = abs(windowFrame.origin.y - screen.origin.y) < tolerance

        let isHalfWidth = abs(windowFrame.width - screen.width / 2) < tolerance
        let isFullWidth = abs(windowFrame.width - screen.width) < tolerance

        // For height, just check if window is at top - don't require exact height match
        // This allows windows coming from smaller monitors to still be detected

        // Check if at left or right edge with approximately half width
        if isHalfWidth {
            if isAtLeft && isAtTop {
                // Could be left half or top-left quarter - check height ratio
                let heightRatio = windowFrame.height / screen.height
                if heightRatio > 0.7 {
                    return .left
                } else if heightRatio > 0.3 && heightRatio <= 0.7 {
                    return .topLeft
                }
            }
            if isAtRight && isAtTop {
                let heightRatio = windowFrame.height / screen.height
                if heightRatio > 0.7 {
                    return .right
                } else if heightRatio > 0.3 && heightRatio <= 0.7 {
                    return .topRight
                }
            }
            // Check bottom positions
            if isAtLeft {
                let bottomEdge = windowFrame.origin.y + windowFrame.height
                let screenBottom = screen.origin.y + screen.height
                if abs(bottomEdge - screenBottom) < tolerance {
                    return .bottomLeft
                }
            }
            if isAtRight {
                let bottomEdge = windowFrame.origin.y + windowFrame.height
                let screenBottom = screen.origin.y + screen.height
                if abs(bottomEdge - screenBottom) < tolerance {
                    return .bottomRight
                }
            }
            // Default: if at left/right edge with half width, treat as half
            if isAtLeft { return .left }
            if isAtRight { return .right }
        }

        if isFullWidth {
            let heightRatio = windowFrame.height / screen.height
            if heightRatio > 0.9 {
                return .maximized
            } else if isAtTop {
                return .top
            } else {
                let bottomEdge = windowFrame.origin.y + windowFrame.height
                let screenBottom = screen.origin.y + screen.height
                if abs(bottomEdge - screenBottom) < tolerance {
                    return .bottom
                }
            }
        }

        return .none
    }

    // Move window to another monitor
    func moveToMonitor(direction: Int) {
        guard let window = getFrontmostWindow(),
              let windowFrame = getWindowFrame(window),
              let nextScreen = getNextScreen(direction: direction) else {
            return
        }

        let currentScreen = getCurrentScreen()
        let currentUsable = getUsableFrame(for: currentScreen)
        let nextUsable = getUsableFrame(for: nextScreen)

        // Calculate relative position on current screen
        let relativeX = (windowFrame.origin.x - currentUsable.origin.x) / currentUsable.width
        let relativeY = (windowFrame.origin.y - currentUsable.origin.y) / currentUsable.height
        let relativeWidth = windowFrame.width / currentUsable.width
        let relativeHeight = windowFrame.height / currentUsable.height

        // Apply to new screen
        let newFrame = CGRect(
            x: nextUsable.origin.x + relativeX * nextUsable.width,
            y: nextUsable.origin.y + relativeY * nextUsable.height,
            width: relativeWidth * nextUsable.width,
            height: relativeHeight * nextUsable.height
        )

        setWindowFrame(window, frame: newFrame)
    }

    // MARK: - Windows-style Smart Snap

    // Check if window is snapped to left side (any height, any width up to ~60% of screen)
    func isSnappedLeft() -> Bool {
        guard let window = getFrontmostWindow(),
              let windowFrame = getWindowFrame(window) else { return false }
        let screen = getUsableFrame()
        let tolerance: CGFloat = 50
        let isAtLeft = abs(windowFrame.origin.x - screen.origin.x) < tolerance
        // Window should be roughly half width (between 40% and 60% of screen width)
        let widthRatio = windowFrame.width / screen.width
        let isRoughlyHalfWidth = widthRatio > 0.35 && widthRatio < 0.65
        return isAtLeft && isRoughlyHalfWidth
    }

    // Check if window is snapped to right side (any height, any width up to ~60% of screen)
    func isSnappedRight() -> Bool {
        guard let window = getFrontmostWindow(),
              let windowFrame = getWindowFrame(window) else { return false }
        let screen = getUsableFrame()
        let tolerance: CGFloat = 50
        let isAtRight = abs(windowFrame.origin.x + windowFrame.width - screen.origin.x - screen.width) < tolerance
        // Window should be roughly half width (between 40% and 60% of screen width)
        let widthRatio = windowFrame.width / screen.width
        let isRoughlyHalfWidth = widthRatio > 0.35 && widthRatio < 0.65
        return isAtRight && isRoughlyHalfWidth
    }

    func handleLeft() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()

        if isSnappedLeft() {
            // Already on left side - move to previous monitor's right half
            if let prevScreen = getNextScreen(direction: -1) {
                let prevFrame = getUsableFrame(for: prevScreen)
                snapToFrame(window, frame: rightHalf(prevFrame))
            }
        } else {
            // Snap to left half of current screen (always full height)
            snapToFrame(window, frame: leftHalf(frame))
        }
    }

    func handleRight() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()

        if isSnappedRight() {
            // Already on right side - move to next monitor's left half
            if let nextScreen = getNextScreen(direction: 1) {
                let nextFrame = getUsableFrame(for: nextScreen)
                snapToFrame(window, frame: leftHalf(nextFrame))
            }
        } else {
            // Snap to right half of current screen (always full height)
            snapToFrame(window, frame: rightHalf(frame))
        }
    }

    func handleUp() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()

        if isSnappedLeft() {
            // Left half -> top-left quarter
            snapToFrame(window, frame: topLeft(frame))
        } else if isSnappedRight() {
            // Right half -> top-right quarter
            snapToFrame(window, frame: topRight(frame))
        } else {
            // Maximize
            snapToFrame(window, frame: frame)
        }
    }

    func handleDown() {
        guard let window = getFrontmostWindow() else { return }
        let frame = getUsableFrame()

        if isSnappedLeft() {
            // Left half -> bottom-left quarter
            snapToFrame(window, frame: bottomLeft(frame))
        } else if isSnappedRight() {
            // Right half -> bottom-right quarter
            snapToFrame(window, frame: bottomRight(frame))
        }
        // Otherwise do nothing
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

    func moveToNextMonitor() {
        moveToMonitor(direction: 1)
    }

    func moveToPrevMonitor() {
        moveToMonitor(direction: -1)
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
            let hasShift = flags.contains(.maskShift)

            let wm = WindowManager.shared

            // Control + Option + Command for thirds
            if hasControl && hasOption && hasCommand && !hasShift {
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

            // Control + Option + Shift for moving between monitors
            if hasControl && hasOption && hasShift && !hasCommand {
                switch keyCode {
                case 123: // Left arrow - move to previous monitor
                    wm.moveToPrevMonitor()
                    return nil
                case 124: // Right arrow - move to next monitor
                    wm.moveToNextMonitor()
                    return nil
                default:
                    break
                }
            }

            // Control + Option for Windows-style snapping
            if hasControl && hasOption && !hasCommand && !hasShift {
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
                case 2: // D - diagnostics
                    wm.showDiagnostics()
                    return nil
                default:
                    break
                }
            }
        }

        return Unmanaged.passRetained(event)
    }
}

// MARK: - Preferences Window

class PreferencesWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snap Preferences"
        window.center()

        self.init(window: window)

        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)

        // Title
        let titleLabel = NSTextField(labelWithString: "Snap")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.frame = NSRect(x: 20, y: 190, width: 360, height: 30)
        contentView.addSubview(titleLabel)

        // Version
        let versionLabel = NSTextField(labelWithString: "Version 1.2.2")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 20, y: 170, width: 360, height: 20)
        contentView.addSubview(versionLabel)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 20, y: 155, width: 360, height: 1)
        contentView.addSubview(separator)

        // Launch at login checkbox
        let launchCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launchCheckbox.frame = NSRect(x: 20, y: 120, width: 360, height: 25)
        launchCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
        contentView.addSubview(launchCheckbox)

        // Accessibility permissions button
        let accessibilityButton = NSButton(title: "Open Accessibility Permissions", target: self, action: #selector(openAccessibilitySettings))
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.frame = NSRect(x: 20, y: 85, width: 220, height: 25)
        contentView.addSubview(accessibilityButton)

        // Keyboard shortcuts section
        let shortcutsLabel = NSTextField(labelWithString: "Keyboard Shortcuts")
        shortcutsLabel.font = NSFont.boldSystemFont(ofSize: 13)
        shortcutsLabel.frame = NSRect(x: 20, y: 55, width: 360, height: 20)
        contentView.addSubview(shortcutsLabel)

        let shortcutsText = NSTextField(labelWithString: "⌃⌥ + Arrows: Snap windows\n⌃⌥⇧ + ←/→: Move between monitors\n⌃⌥⌘ + 1-5: Thirds")
        shortcutsText.font = NSFont.systemFont(ofSize: 11)
        shortcutsText.textColor = .secondaryLabelColor
        shortcutsText.frame = NSRect(x: 20, y: 5, width: 360, height: 50)
        contentView.addSubview(shortcutsText)

        window.contentView = contentView
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        Preferences.shared.launchAtLogin = enabled

        // Update login items
        if enabled {
            addToLoginItems()
        } else {
            removeFromLoginItems()
        }
    }

    private func addToLoginItems() {
        let script = "tell application \"System Events\" to make login item at end with properties {path:\"\(Bundle.main.bundlePath)\", hidden:false}"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    private func removeFromLoginItems() {
        let script = "tell application \"System Events\" to delete login item \"Snap\""
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
}

// MARK: - Menu Bar Icon

class MenuBarIcon {
    static func createIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.labelColor.setStroke()

            let path = NSBezierPath()
            path.lineWidth = 1.5

            // Draw a window grid icon
            let inset: CGFloat = 2
            let innerRect = rect.insetBy(dx: inset, dy: inset)

            // Outer rectangle
            let outerPath = NSBezierPath(roundedRect: innerRect, xRadius: 2, yRadius: 2)
            outerPath.lineWidth = 1.5
            outerPath.stroke()

            // Vertical divider
            path.move(to: NSPoint(x: rect.midX, y: innerRect.minY + 2))
            path.line(to: NSPoint(x: rect.midX, y: innerRect.maxY - 2))

            // Horizontal divider on right side
            path.move(to: NSPoint(x: rect.midX + 1, y: rect.midY))
            path.line(to: NSPoint(x: innerRect.maxX - 2, y: rect.midY))

            path.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Just check permissions - macOS will show its own prompt
        _ = checkAccessibilityPermissions()

        setupStatusBar()
        HotkeyManager.shared.start()

        print("Snap is running! (Windows-style)")
        print("")
        print("Keyboard Shortcuts (Control + Option + Arrow):")
        print("  ← : Snap left (or move to prev monitor if already left)")
        print("  → : Snap right (or move to next monitor if already right)")
        print("  ↑ : Quarter top (if half) or maximize")
        print("  ↓ : Quarter bottom (if half)")
        print("")
        print("Multi-Monitor (Control + Option + Shift + Arrow):")
        print("  ← : Move window to previous monitor")
        print("  → : Move window to next monitor")
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = MenuBarIcon.createIcon()
        }

        let menu = NSMenu()

        let versionItem = NSMenuItem(title: "Snap v1.2.2", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Snap Left (⌃⌥←)", action: #selector(snapLeft), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Right (⌃⌥→)", action: #selector(snapRight), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Up (⌃⌥↑)", action: #selector(snapUp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snap Down (⌃⌥↓)", action: #selector(snapDown), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Move to Previous Monitor (⌃⌥⇧←)", action: #selector(moveToPrevMonitor), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Move to Next Monitor (⌃⌥⇧→)", action: #selector(moveToNextMonitor), keyEquivalent: ""))

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

        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Diagnostics (⌃⌥D)", action: #selector(showDiagnostics), keyEquivalent: ""))

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
    @objc func moveToNextMonitor() { WindowManager.shared.moveToNextMonitor() }
    @objc func moveToPrevMonitor() { WindowManager.shared.moveToPrevMonitor() }

    @objc func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showDiagnostics() {
        WindowManager.shared.showDiagnostics()
    }

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
