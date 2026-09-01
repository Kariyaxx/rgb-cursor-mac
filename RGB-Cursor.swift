import Cocoa
import QuartzCore

// MARK: - Cursor View

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

        // Small normal macOS-style arrow.
        // The tip is at the TOP-LEFT.
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 3, y: 3))
        path.addLine(to: CGPoint(x: 3, y: 21))
        path.addLine(to: CGPoint(x: 19, y: 11))
        path.addLine(to: CGPoint(x: 12, y: 11))
        path.addLine(to: CGPoint(x: 16, y: 4))
        path.addLine(to: CGPoint(x: 13, y: 2))
        path.addLine(to: CGPoint(x: 9, y: 9))
        path.closeSubpath()

        // Soft pastel glow
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

        // Do not block clicks.
        ignoresMouseEvents = true

        // Put the RGB cursor above the normal cursor level.
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
    private var timer: Timer!

    private var statusItem: NSStatusItem!

    private var isCursorEnabled = true


    // MARK: - Launch

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        setupMenuBar()

        // Create cursor view.
        cursorView = CursorView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 24,
                height: 24
            )
        )

        // Create transparent window.
        cursorWindow = CursorWindow()

        cursorWindow.contentView = cursorView

        // Hide the real cursor first.
        hideRealCursor()

        // Show our cursor.
        cursorWindow.orderFrontRegardless()

        // RGB animation timer.
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.04,
            repeats: true
        ) { [weak self] _ in

            self?.updateCursor()
        }

        updateCursor()
    }


    // MARK: - Hide Real Cursor

    private func hideRealCursor() {

        // AppKit hide.
        NSCursor.hide()

        // Hide the cursor on every active display.
        var displayCount: UInt32 = 0

        CGGetActiveDisplayList(
            0,
            nil,
            &displayCount
        )

        if displayCount > 0 {

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

        } else {

            CGDisplayHideCursor(
                CGMainDisplayID()
            )
        }
    }


    // MARK: - Show Real Cursor

    private func showRealCursor() {

        // AppKit show.
        NSCursor.unhide()

        // Show the cursor on every active display.
        var displayCount: UInt32 = 0

        CGGetActiveDisplayList(
            0,
            nil,
            &displayCount
        )

        if displayCount > 0 {

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

        } else {

            CGDisplayShowCursor(
                CGMainDisplayID()
            )
        }
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

            enableCursor()

        } else {

            disableCursor()
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

                if isCursorEnabled {

                    item.title = "RGB Cursor: ON"

                } else {

                    item.title = "RGB Cursor: OFF"
                }
            }
        }
    }


    // MARK: - Enable

    private func enableCursor() {

        isCursorEnabled = true

        hideRealCursor()

        cursorWindow.orderFrontRegardless()

        updateCursor()
    }


    // MARK: - Disable

    private func disableCursor() {

        isCursorEnabled = false

        cursorWindow.orderOut(nil)

        showRealCursor()
    }


    // MARK: - Update Cursor

    private func updateCursor() {

        guard isCursorEnabled else {
            return
        }

        cursorView.updateHue()

        let mouse = NSEvent.mouseLocation

        // The cursor tip is at (3, 3).
        // Put that exact point on the real mouse position.

        let windowX = mouse.x - 3
        let windowY = mouse.y - 3

        cursorWindow.setFrameOrigin(
            NSPoint(
                x: windowX,
                y: windowY
            )
        )
    }


    // MARK: - Quit

    @objc private func quitApp() {

        restoreCursor()

        NSApplication.shared.terminate(nil)
    }


    // MARK: - Restore

    private func restoreCursor() {

        timer?.invalidate()

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


// MARK: - Start Application

let app = NSApplication.shared

let delegate = AppDelegate()

app.delegate = delegate

app.setActivationPolicy(.accessory)

app.run()
