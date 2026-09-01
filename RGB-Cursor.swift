import Cocoa
import QuartzCore

// MARK: - RGB Cursor View

final class CursorView: NSView {

    private var hue: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.clear(bounds)

        // Soft pastel rainbow
        let color = NSColor(
            hue: hue / 360.0,
            saturation: 0.38,
            brightness: 1.0,
            alpha: 1.0
        )

        // Small cursor pointing upper-left
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 3, y: 21))
        path.addLine(to: CGPoint(x: 3, y: 3))
        path.addLine(to: CGPoint(x: 19, y: 13))
        path.addLine(to: CGPoint(x: 12, y: 13))
        path.addLine(to: CGPoint(x: 16, y: 20))
        path.addLine(to: CGPoint(x: 13, y: 22))
        path.addLine(to: CGPoint(x: 9, y: 15))
        path.closeSubpath()

        // Very soft glow
        context.saveGState()

        context.setShadow(
            offset: .zero,
            blur: 2.0,
            color: color.withAlphaComponent(0.3).cgColor
        )

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.2)

        context.addPath(path)
        context.strokePath()

        context.restoreGState()

        // Soft outline
        context.setStrokeColor(
            NSColor.black.withAlphaComponent(0.6).cgColor
        )

        context.setLineWidth(1.4)

        context.addPath(path)
        context.strokePath()

        // White center
        context.setFillColor(
            NSColor.white.withAlphaComponent(0.96).cgColor
        )

        context.addPath(path)
        context.fillPath()

        // Pastel RGB border
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.0)

        context.addPath(path)
        context.strokePath()
    }

    func updateHue() {

        // Slow smooth RGB animation
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

        // NEVER block mouse clicks
        ignoresMouseEvents = true

        // Put our cursor above the normal cursor window level
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

        // Create the 24x24 cursor
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

        cursorWindow.orderFrontRegardless()

        // Hide the REAL macOS cursor
        hideRealCursor()

        // RGB animation
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

        // Hide through AppKit
        NSCursor.hide()

        // Also hide through Core Graphics
        CGDisplayHideCursor(
            CGMainDisplayID()
        )
    }


    // MARK: - Show Real Cursor

    private func showRealCursor() {

        // Show through AppKit
        NSCursor.unhide()

        // Show through Core Graphics
        CGDisplayShowCursor(
            CGMainDisplayID()
        )
    }


    // MARK: - Menu Bar

    private func setupMenuBar() {

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        if let button = statusItem.button {

            button.title = "🌈"
            button.toolTip = "RGB Cursor"
        }

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


    // MARK: - Menu Update

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

        cursorWindow.orderFrontRegardless()

        hideRealCursor()

        updateCursor()
    }


    // MARK: - Disable

    private func disableCursor() {

        isCursorEnabled = false

        cursorWindow.orderOut(nil)

        showRealCursor()
    }


    // MARK: - Position

    private func updateCursor() {

        guard isCursorEnabled else {
            return
        }

        cursorView.updateHue()

        let mouse = NSEvent.mouseLocation

        // The tip of our arrow is at x=3, y=21.
        // Put that tip exactly at the real mouse position.

        let x = mouse.x - 3
        let y = mouse.y - 21

        cursorWindow.setFrameOrigin(
            NSPoint(
                x: x,
                y: y
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
