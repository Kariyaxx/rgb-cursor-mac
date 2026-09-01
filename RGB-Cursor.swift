import Cocoa
import QuartzCore

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
            saturation: 0.45,
            brightness: 1.0,
            alpha: 1.0
        )

        // Small 24x24 cursor
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 4, y: 20))
        path.addLine(to: CGPoint(x: 4, y: 4))
        path.addLine(to: CGPoint(x: 18, y: 14))
        path.addLine(to: CGPoint(x: 12, y: 14))
        path.addLine(to: CGPoint(x: 16, y: 20))
        path.addLine(to: CGPoint(x: 13, y: 22))
        path.addLine(to: CGPoint(x: 9, y: 16))
        path.closeSubpath()

        // Very subtle glow
        context.saveGState()

        context.setShadow(
            offset: .zero,
            blur: 2,
            color: color.withAlphaComponent(0.35).cgColor
        )

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.2)

        context.addPath(path)
        context.strokePath()

        context.restoreGState()

        // Soft dark outline
        context.setStrokeColor(
            NSColor.black.withAlphaComponent(0.65).cgColor
        )
        context.setLineWidth(1.5)

        context.addPath(path)
        context.strokePath()

        // White center
        context.setFillColor(
            NSColor.white.withAlphaComponent(0.95).cgColor
        )

        context.addPath(path)
        context.fillPath()

        // Pastel RGB edge
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)

        context.addPath(path)
        context.strokePath()
    }

    func updateHue() {
        hue += 1

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
            rawValue: Int(CGWindowLevelForKey(.cursorWindow))
        )

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }
}


// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var cursorWindow: CursorWindow!
    private var cursorView: CursorView!
    private var timer: Timer!

    private var statusItem: NSStatusItem!
    private var isCursorEnabled = true


    func applicationDidFinishLaunching(_ notification: Notification) {

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

        cursorWindow.orderFrontRegardless()

        CGDisplayHideCursor(CGMainDisplayID())

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

        let titleItem = NSMenuItem(
            title: "RGB Cursor",
            action: nil,
            keyEquivalent: ""
        )

        titleItem.isEnabled = false

        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: "RGB Cursor: ON",
            action: #selector(toggleCursor),
            keyEquivalent: ""
        )

        toggleItem.target = self
        toggleItem.tag = 100

        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())

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

                item.title = isCursorEnabled
                    ? "RGB Cursor: ON"
                    : "RGB Cursor: OFF"
            }
        }
    }


    private func enableCursor() {

        cursorWindow.orderFrontRegardless()

        CGDisplayHideCursor(CGMainDisplayID())
    }


    private func disableCursor() {

        cursorWindow.orderOut(nil)

        CGDisplayShowCursor(CGMainDisplayID())
    }


    // MARK: Cursor Position

    private func updateCursor() {

        guard isCursorEnabled else {
            return
        }

        cursorView.updateHue()

        let mouse = NSEvent.mouseLocation

        let x = mouse.x - 4
        let y = mouse.y - 20

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


    private func restoreCursor() {

        timer?.invalidate()

        CGDisplayShowCursor(CGMainDisplayID())

        cursorWindow?.orderOut(nil)
    }


    func applicationWillTerminate(_ notification: Notification) {

        restoreCursor()
    }
}


// MARK: - Start

let app = NSApplication.shared

let delegate = AppDelegate()

app.delegate = delegate

app.setActivationPolicy(.accessory)

app.run()
