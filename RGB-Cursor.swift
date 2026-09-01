import Cocoa
import QuartzCore

// MARK: - RGB Cursor View

final class CursorView: NSView {

    private var hue: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let size: CGFloat = 32

        context.clear(CGRect(x: 0, y: 0, width: size, height: size))

        let color = NSColor(
            hue: hue / 360.0,
            saturation: 1.0,
            brightness: 1.0,
            alpha: 1.0
        )

        // Cursor shape
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 5, y: 27))
        path.addLine(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 24, y: 20))
        path.addLine(to: CGPoint(x: 16, y: 20))
        path.addLine(to: CGPoint(x: 21, y: 27))
        path.addLine(to: CGPoint(x: 17, y: 30))
        path.addLine(to: CGPoint(x: 12, y: 22))
        path.closeSubpath()

        // RGB glow
        context.saveGState()

        context.setShadow(
            offset: .zero,
            blur: 4,
            color: color.withAlphaComponent(0.8).cgColor
        )

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)

        context.addPath(path)
        context.strokePath()

        context.restoreGState()

        // Black outline
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(3)

        context.addPath(path)
        context.strokePath()

        // White body
        context.setFillColor(NSColor.white.cgColor)

        context.addPath(path)
        context.fillPath()

        // RGB edge
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)

        context.addPath(path)
        context.strokePath()
    }

    func updateHue() {
        hue += 5

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
                width: 32,
                height: 32
            ),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Don't block mouse clicks
        ignoresMouseEvents = true

        // Stay above normal windows
        level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.cursorWindow))
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


    // MARK: Start

    func applicationDidFinishLaunching(_ notification: Notification) {

        setupMenuBar()

        cursorView = CursorView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 32,
                height: 32
            )
        )

        cursorWindow = CursorWindow()
        cursorWindow.contentView = cursorView

        cursorWindow.orderFrontRegardless()

        // Hide normal cursor
        CGDisplayHideCursor(CGMainDisplayID())

        // RGB animation
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.04,
            repeats: true
        ) { [weak self] _ in
            self?.updateCursor()
        }

        updateCursor()
    }


    // MARK: Menu Bar

    private func setupMenuBar() {

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        if let button = statusItem.button {
            button.title = "🌈"
            button.toolTip = "RGB Cursor"
        }

        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(
            title: "RGB Cursor",
            action: nil,
            keyEquivalent: ""
        )

        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // ON/OFF
        let toggleItem = NSMenuItem(
            title: "RGB Cursor: ON",
            action: #selector(toggleCursor),
            keyEquivalent: ""
        )

        toggleItem.target = self
        toggleItem.tag = 100

        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit RGB Cursor",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        quitItem.target = self

        menu.addItem(quitItem)

        statusItem.menu = menu
    }


    // MARK: Toggle

    @objc private func toggleCursor() {

        isCursorEnabled.toggle()

        if isCursorEnabled {
            enableCursor()
        } else {
            disableCursor()
        }

        updateMenu()
    }


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


    // MARK: Enable

    private func enableCursor() {

        isCursorEnabled = true

        cursorWindow.orderFrontRegardless()

        CGDisplayHideCursor(CGMainDisplayID())
    }


    // MARK: Disable

    private func disableCursor() {

        isCursorEnabled = false

        cursorWindow.orderOut(nil)

        CGDisplayShowCursor(CGMainDisplayID())
    }


    // MARK: Update Cursor

    private func updateCursor() {

        guard isCursorEnabled else {
            return
        }

        cursorView.updateHue()

        let mouse = NSEvent.mouseLocation

        // Position cursor tip at real mouse position
        let x = mouse.x - 5
        let y = mouse.y - 27

        cursorWindow.setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )
    }


    // MARK: Quit

    @objc private func quitApp() {

        restoreCursor()

        NSApplication.shared.terminate(nil)
    }


    // MARK: Restore

    private func restoreCursor() {

        timer?.invalidate()

        CGDisplayShowCursor(CGMainDisplayID())

        cursorWindow?.orderOut(nil)
    }


    func applicationWillTerminate(_ notification: Notification) {

        restoreCursor()
    }
}


// MARK: - Start App

let app = NSApplication.shared

let delegate = AppDelegate()

app.delegate = delegate

app.setActivationPolicy(.accessory)

app.run()
