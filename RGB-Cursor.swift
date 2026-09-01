import Cocoa
import QuartzCore

final class CursorView: NSView {

    private var hue: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.clear(bounds)

        let color = NSColor(
            hue: hue / 360.0,
            saturation: 0.38,
            brightness: 1.0,
            alpha: 1.0
        )

        // Small normal arrow.
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 3, y: 3))
        path.addLine(to: CGPoint(x: 3, y: 21))
        path.addLine(to: CGPoint(x: 19, y: 11))
        path.addLine(to: CGPoint(x: 12, y: 11))
        path.addLine(to: CGPoint(x: 16, y: 4))
        path.addLine(to: CGPoint(x: 13, y: 2))
        path.addLine(to: CGPoint(x: 9, y: 9))
        path.closeSubpath()

        context.saveGState()

        context.setShadow(
            offset: .zero,
            blur: 2.0,
            color: color.withAlphaComponent(0.3).cgColor
        )

        context.setFillColor(
            NSColor.white.withAlphaComponent(0.96).cgColor
        )

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.2)

        context.addPath(path)
        context.drawPath(using: .fillStroke)

        context.restoreGState()
    }

    func updateHue() {

        hue += 0.8

        if hue >= 360 {
            hue = 0
        }

        needsDisplay = true
    }
}


// MARK: - Cursor Window

final class CursorWindow: NSWindow {

    init() {

        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 24,
                height: 24
            ),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        ignoresMouseEvents = true

        level = NSWindow.Level(
            rawValue: Int(
                CGWindowLevelForKey(.cursorWindow)
            ) + 10
        )

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }
}


// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var cursorWindow: CursorWindow!
    private var cursorView: CursorView!

    private var animationTimer: Timer!
    private var hideTimer: Timer!

    private var statusItem: NSStatusItem!

    private var isCursorEnabled = true


    // MARK: - Launch

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        setupMenuBar()

        cursorView = CursorView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 24,
                height: 24
            )
        )

        cursorWindow = CursorWindow()

        cursorWindow.contentView = cursorView

        hideRealCursor()

        cursorWindow.orderFrontRegardless()

        // RGB animation.
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.04,
            repeats: true
        ) { [weak self] _ in

            guard let self = self else {
                return
            }

            self.cursorView.updateHue()
            self.updateCursor()
        }

        // Continuously re-hide the real cursor.
        // This is important because macOS can restore it
        // when another application becomes active.
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: 0.25,
            repeats: true
        ) { [weak self] _ in

            guard let self = self else {
                return
            }

            if self.isCursorEnabled {
                self.hideRealCursor()
                self.cursorWindow.orderFrontRegardless()
            }
        }

        updateCursor()
    }


    // MARK: - Hide Real Cursor

    private func hideRealCursor() {

        NSCursor.hide()

        var displayCount: UInt32 = 0

        CGGetActiveDisplayList(
            0,
            nil,
            &displayCount
        )

        guard displayCount > 0 else {

            CGDisplayHideCursor(
                CGMainDisplayID()
            )

            return
        }

        var displays = [
            CGDirectDisplayID
        ](
            repeating: 0,
            count: Int(displayCount)
        )

        CGGetActiveDisplayList(
            displayCount,
            &displays,
            &displayCount
        )

        for display in displays {

            CGDisplayHideCursor(display)
        }
    }


    // MARK: - Show Real Cursor

    private func showRealCursor() {

        NSCursor.unhide()

        var displayCount: UInt32 = 0

        CGGetActiveDisplayList(
            0,
            nil,
            &displayCount
        )

        guard displayCount > 0 else {

            CGDisplayShowCursor(
                CGMainDisplayID()
            )

            return
        }

        var displays = [
            CGDirectDisplayID
        ](
            repeating: 0,
            count: Int(displayCount)
        )

        CGGetActiveDisplayList(
            displayCount,
            &displays,
            &displayCount
        )

        for display in displays {

            CGDisplayShowCursor(display)
        }
    }


    // MARK: - Cursor Position

    private func updateCursor() {

        guard isCursorEnabled else {
            return
        }

        let mouse = NSEvent.mouseLocation

        // Keep the tip exactly at the mouse position.
        let x = mouse.x - 3
        let y = mouse.y - 3

        cursorWindow.setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )
    }


    // MARK: - Menu Bar

    private func setupMenuBar() {

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        statusItem.button?.title = "🌈"

        statusItem.button?.toolTip = "RGB Cursor"

        let menu = NSMenu()

        let titleItem = NSMenuItem(
            title: "RGB Cursor",
            action: nil,
            keyEquivalent: ""
        )

        titleItem.isEnabled = false

        menu.addItem(titleItem)

        menu.addItem(
            NSMenuItem.separator()
        )

        let toggleItem = NSMenuItem(
            title: "RGB Cursor: ON",
            action: #selector(toggleCursor),
            keyEquivalent: ""
        )

        toggleItem.target = self
        toggleItem.tag = 100

        menu.addItem(toggleItem)

        menu.addItem(
            NSMenuItem.separator()
        )

        let quitItem = NSMenuItem(
            title: "Quit RGB Cursor",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        quitItem.target = self

        menu.addItem(quitItem)

        statusItem.menu = menu
    }


    // MARK: - Toggle

    @objc private func toggleCursor() {

        isCursorEnabled.toggle()

        if isCursorEnabled {

            hideRealCursor()

            cursorWindow.orderFrontRegardless()

            updateCursor()

        } else {

            cursorWindow.orderOut(nil)

            showRealCursor()
        }

        updateMenu()
    }


    // MARK: - Update Menu

    private func updateMenu() {

        guard let menu = statusItem.menu else {
            return
        }

        for item in menu.items {

            if item.tag == 100 {

                item.title = isCursorEnabled
                    ? "RGB Cursor: ON"
                    : "RGB Cursor: OFF"
            }
        }
    }


    // MARK: - Quit

    @objc private func quitApp() {

        restoreCursor()

        NSApplication.shared.terminate(nil)
    }


    // MARK: - Restore

    private func restoreCursor() {

        isCursorEnabled = false

        animationTimer?.invalidate()
        hideTimer?.invalidate()

        cursorWindow?.orderOut(nil)

        showRealCursor()
    }


    // MARK: - Termination

    func applicationWillTerminate(
        _ notification: Notification
    ) {

        restoreCursor()
    }
}


// MARK: - Start

let app = NSApplication.shared

let delegate = AppDelegate()

app.delegate = delegate

app.setActivationPolicy(.accessory)

app.run()
