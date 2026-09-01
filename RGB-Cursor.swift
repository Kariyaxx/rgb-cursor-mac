import Cocoa
import QuartzCore

// MARK: - RGB Cursor View

final class CursorView: NSView {

    private var hue: CGFloat = 0
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.04,
            repeats: true
        ) { [weak self] _ in

            guard let self = self else {
                return
            }

            self.hue += 2

            if self.hue >= 360 {
                self.hue -= 360
            }

            self.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        // Small 24x24 cursor
        let path = CGMutablePath()

        path.move(to: CGPoint(x: 3, y: 3))
        path.addLine(to: CGPoint(x: 3, y: 21))
        path.addLine(to: CGPoint(x: 19, y: 11))
        path.addLine(to: CGPoint(x: 12, y: 11))
        path.addLine(to: CGPoint(x: 16, y: 4))
        path.addLine(to: CGPoint(x: 13, y: 2))
        path.addLine(to: CGPoint(x: 9, y: 9))
        path.closeSubpath()

        // Soft pastel RGB color
        let color = NSColor(
            hue: hue / 360.0,
            saturation: 0.45,
            brightness: 1.0,
            alpha: 1.0
        )

        // Soft glow
        context.saveGState()

        context.setShadow(
            offset: .zero,
            blur: 3,
            color: color.withAlphaComponent(0.4).cgColor
        )

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)
        context.setLineJoin(.round)

        context.addPath(path)
        context.strokePath()

        context.restoreGState()

        // White center
        context.saveGState()

        context.setFillColor(
            NSColor.white.withAlphaComponent(0.92).cgColor
        )

        context.addPath(path)
        context.fillPath()

        context.restoreGState()

        // RGB outline
        context.saveGState()

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.2)
        context.setLineJoin(.round)

        context.addPath(path)
        context.strokePath()

        context.restoreGState()
    }
}


// MARK: - Cursor Window

final class CursorWindow: NSWindow {

    let cursorView: CursorView

    init() {

        cursorView = CursorView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 24,
                height: 24
            )
        )

        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 24,
                height: 24
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // The RGB cursor must not block clicks.
        ignoresMouseEvents = true

        // Put the RGB cursor above normal windows.
        level = NSWindow.Level(
            rawValue:
                Int(CGWindowLevelForKey(.cursorWindow)) + 10
        )

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        contentView = cursorView

        orderFrontRegardless()
    }

    func updatePosition() {

        let mouse = NSEvent.mouseLocation

        let x = mouse.x - 3
        let y = mouse.y - 3

        setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )
    }
}


// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var cursorWindow: CursorWindow?

    private var positionTimer: Timer?
    private var hideTimer: Timer?

    private var statusItem: NSStatusItem?

    private var isCursorHidden = false
    private var isRunning = true


    // MARK: Launch

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        setupMenuBar()

        cursorWindow = CursorWindow()

        startPositionTracking()

        hideSystemCursor()

        startCursorWatchdog()

        cursorWindow?.updatePosition()
        cursorWindow?.orderFrontRegardless()
    }


    // MARK: Menu Bar

    private func setupMenuBar() {

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        statusItem?.button?.title = "🌈"

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "RGB Cursor: ON",
            action: #selector(toggleCursor),
            keyEquivalent: ""
        )

        toggleItem.target = self

        menu.addItem(toggleItem)

        menu.addItem(
            NSMenuItem.separator()
        )

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        quitItem.target = self

        menu.addItem(quitItem)

        statusItem?.menu = menu
    }


    // MARK: Toggle

    @objc private func toggleCursor() {

        isRunning.toggle()

        if isRunning {

            hideSystemCursor()

            cursorWindow?.orderFrontRegardless()

            statusItem?.menu?.item(at: 0)?.title =
                "RGB Cursor: ON"

        } else {

            showSystemCursor()

            cursorWindow?.orderOut(nil)

            statusItem?.menu?.item(at: 0)?.title =
                "RGB Cursor: OFF"
        }
    }


    // MARK: Cursor Position

    private func startPositionTracking() {

        positionTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 120.0,
            repeats: true
        ) { [weak self] _ in

            guard let self = self else {
                return
            }

            guard self.isRunning else {
                return
            }

            self.cursorWindow?.updatePosition()
        }
    }


    // MARK: Hide System Cursor

    private func hideSystemCursor() {

        guard !isCursorHidden else {
            return
        }

        isCursorHidden = true

        NSCursor.hide()

        CGDisplayHideCursor(
            CGMainDisplayID()
        )
    }


    // MARK: Show System Cursor

    private func showSystemCursor() {

        guard isCursorHidden else {
            return
        }

        isCursorHidden = false

        NSCursor.unhide()

        CGDisplayShowCursor(
            CGMainDisplayID()
        )
    }


    // MARK: Cursor Watchdog

    private func startCursorWatchdog() {

        hideTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in

            guard let self = self else {
                return
            }

            guard self.isRunning else {
                return
            }

            self.cursorWindow?.updatePosition()
            self.cursorWindow?.orderFrontRegardless()

            // Re-apply hiding if necessary.
            self.hideSystemCursor()
        }
    }


    // MARK: App Activation

    func applicationDidBecomeActive(
        _ notification: Notification
    ) {

        guard isRunning else {
            return
        }

        hideSystemCursor()

        cursorWindow?.orderFrontRegardless()
    }


    func applicationDidResignActive(
        _ notification: Notification
    ) {

        guard isRunning else {
            return
        }

        hideSystemCursor()

        cursorWindow?.orderFrontRegardless()
    }


    // MARK: Quit

    @objc private func quitApp() {

        positionTimer?.invalidate()
        hideTimer?.invalidate()

        showSystemCursor()

        cursorWindow?.close()

        NSApp.terminate(nil)
    }


    // MARK: Application Termination

    func applicationWillTerminate(
        _ notification: Notification
    ) {

        positionTimer?.invalidate()
        hideTimer?.invalidate()

        showSystemCursor()
    }
}


// MARK: - Start Application

let app = NSApplication.shared

let delegate = AppDelegate()

app.delegate = delegate

app.setActivationPolicy(.accessory)

app.run()
