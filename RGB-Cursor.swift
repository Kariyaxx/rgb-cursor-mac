import Cocoa
import QuartzCore
import Darwin

// ============================================================
// PRIVATE SKYLIGHT SUPPORT
// ============================================================

typealias CGSConnectionID = Int32

typealias CGSMainConnectionIDFunction =
    @convention(c) () -> CGSConnectionID

typealias CGSSetConnectionPropertyFunction =
    @convention(c) (
        CGSConnectionID,
        CGSConnectionID,
        CFString,
        CFTypeRef
    ) -> Int32


final class SkyLightCursorController {

    private var frameworkHandle: UnsafeMutableRawPointer?

    private var mainConnectionFunction:
        CGSMainConnectionIDFunction?

    private var setConnectionPropertyFunction:
        CGSSetConnectionPropertyFunction?


    init() {

        frameworkHandle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_NOW
        )

        guard let handle = frameworkHandle else {
            print("RGB Cursor: Could not load SkyLight.framework")
            return
        }

        // Find CGSMainConnectionID

        if let symbol = dlsym(
            handle,
            "CGSMainConnectionID"
        ) {

            mainConnectionFunction =
                unsafeBitCast(
                    symbol,
                    to: CGSMainConnectionIDFunction.self
                )
        }

        // Find CGSSetConnectionProperty

        if let symbol = dlsym(
            handle,
            "CGSSetConnectionProperty"
        ) {

            setConnectionPropertyFunction =
                unsafeBitCast(
                    symbol,
                    to: CGSSetConnectionPropertyFunction.self
                )
        }
    }


    deinit {

        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }


    @discardableResult
    func enableBackgroundCursorHiding() -> Bool {

        guard
            let mainConnectionFunction =
                mainConnectionFunction,

            let setConnectionPropertyFunction =
                setConnectionPropertyFunction
        else {

            print(
                "RGB Cursor: SkyLight functions unavailable"
            )

            return false
        }


        let connection =
            mainConnectionFunction()


        guard connection != 0 else {

            print(
                "RGB Cursor: Invalid WindowServer connection"
            )

            return false
        }


        let key: CFString =
            "SetsCursorInBackground" as CFString


        let result =
            setConnectionPropertyFunction(
                connection,
                connection,
                key,
                kCFBooleanTrue
            )


        if result == 0 {

            print(
                "RGB Cursor: Background cursor hiding enabled"
            )

            return true

        } else {

            print(
                "RGB Cursor: CGSSetConnectionProperty failed: \(result)"
            )

            return false
        }
    }
}


// ============================================================
// RGB CURSOR VIEW
// ============================================================

final class CursorView: NSView {

    private var hue: CGFloat = 0

    private var timer: Timer?


    override init(frame frameRect: NSRect) {

        super.init(frame: frameRect)

        wantsLayer = true

        layer?.backgroundColor =
            NSColor.clear.cgColor


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

        fatalError(
            "init(coder:) has not been implemented"
        )
    }


    deinit {

        timer?.invalidate()
    }


    override func draw(
        _ dirtyRect: NSRect
    ) {

        super.draw(dirtyRect)


        guard
            let context =
                NSGraphicsContext.current?.cgContext
        else {
            return
        }


        // ====================================================
        // SMALL 24x24 CURSOR
        // ====================================================

        let path = CGMutablePath()


        path.move(
            to: CGPoint(
                x: 3,
                y: 3
            )
        )


        path.addLine(
            to: CGPoint(
                x: 3,
                y: 21
            )
        )


        path.addLine(
            to: CGPoint(
                x: 19,
                y: 11
            )
        )


        path.addLine(
            to: CGPoint(
                x: 12,
                y: 11
            )
        )


        path.addLine(
            to: CGPoint(
                x: 16,
                y: 4
            )
        )


        path.addLine(
            to: CGPoint(
                x: 13,
                y: 2
            )
        )


        path.addLine(
            to: CGPoint(
                x: 9,
                y: 9
            )
        )


        path.closeSubpath()


        // ====================================================
        // SOFT PASTEL RGB
        // ====================================================

        let color = NSColor(
            hue: hue / 360.0,
            saturation: 0.45,
            brightness: 1.0,
            alpha: 1.0
        )


        // ====================================================
        // SOFT GLOW
        // ====================================================

        context.saveGState()


        context.setShadow(
            offset: .zero,
            blur: 3,
            color:
                color
                    .withAlphaComponent(0.4)
                    .cgColor
        )


        context.setStrokeColor(
            color.cgColor
        )


        context.setLineWidth(1.5)

        context.setLineJoin(.round)


        context.addPath(path)

        context.strokePath()


        context.restoreGState()


        // ====================================================
        // WHITE CENTER
        // ====================================================

        context.saveGState()


        context.setFillColor(
            NSColor.white
                .withAlphaComponent(0.92)
                .cgColor
        )


        context.addPath(path)

        context.fillPath()


        context.restoreGState()


        // ====================================================
        // RGB OUTLINE
        // ====================================================

        context.saveGState()


        context.setStrokeColor(
            color.cgColor
        )


        context.setLineWidth(1.2)

        context.setLineJoin(.round)


        context.addPath(path)

        context.strokePath()


        context.restoreGState()
    }
}


// ============================================================
// CURSOR WINDOW
// ============================================================

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

            styleMask: [
                .borderless
            ],

            backing: .buffered,

            defer: false
        )


        isOpaque = false

        backgroundColor = .clear

        hasShadow = false


        // RGB cursor must never block clicks.

        ignoresMouseEvents = true


        // Put RGB cursor above normal windows/cursor.

        level = NSWindow.Level(
            rawValue:
                Int(
                    CGWindowLevelForKey(
                        .cursorWindow
                    )
                ) + 10
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

        let mouse =
            NSEvent.mouseLocation


        // Keep the cursor tip aligned with
        // the actual mouse position.

        let x =
            mouse.x - 3


        let y =
            mouse.y - 3


        setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )
    }
}


// ============================================================
// APP DELEGATE
// ============================================================

final class AppDelegate:
    NSObject,
    NSApplicationDelegate {


    private var cursorWindow:
        CursorWindow?


    private var positionTimer:
        Timer?


    private var hideTimer:
        Timer?


    private var statusItem:
        NSStatusItem?


    private var isCursorHidden =
        false


    private var isRunning =
        true


    private let skyLight =
        SkyLightCursorController()


    // ========================================================
    // APP START
    // ========================================================

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        setupMenuBar()


        cursorWindow =
            CursorWindow()


        // Enable background cursor hiding.

        skyLight
            .enableBackgroundCursorHiding()


        startPositionTracking()


        hideSystemCursor()


        startCursorWatchdog()


        cursorWindow?
            .updatePosition()


        cursorWindow?
            .orderFrontRegardless()
    }


    // ========================================================
    // MENU BAR
    // ========================================================

    private func setupMenuBar() {

        statusItem =
            NSStatusBar.system.statusItem(
                withLength:
                    NSStatusItem.variableLength
            )


        statusItem?.button?.title =
            "🌈"


        let menu =
            NSMenu()


        // ON/OFF

        let toggleItem =
            NSMenuItem(
                title:
                    "RGB Cursor: ON",

                action:
                    #selector(
                        toggleCursor
                    ),

                keyEquivalent:
                    ""
            )


        toggleItem.target =
            self


        menu.addItem(
            toggleItem
        )


        menu.addItem(
            NSMenuItem.separator()
        )


        // QUIT

        let quitItem =
            NSMenuItem(
                title:
                    "Quit",

                action:
                    #selector(
                        quitApp
                    ),

                keyEquivalent:
                    "q"
            )


        quitItem.target =
            self


        menu.addItem(
            quitItem
        )


        statusItem?.menu =
            menu
    }


    // ========================================================
    // TOGGLE RGB CURSOR
    // ========================================================

    @objc private func toggleCursor() {

        isRunning.toggle()


        if isRunning {

            // Re-enable background hiding.

            skyLight
                .enableBackgroundCursorHiding()


            hideSystemCursor()


            cursorWindow?
                .orderFrontRegardless()


            statusItem?
                .menu?
                .item(at: 0)?
                .title =
                "RGB Cursor: ON"


        } else {

            showSystemCursor()


            cursorWindow?
                .orderOut(nil)


            statusItem?
                .menu?
                .item(at: 0)?
                .title =
                "RGB Cursor: OFF"
        }
    }


    // ========================================================
    // POSITION TRACKING
    // ========================================================

    private func startPositionTracking() {

        positionTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    1.0 / 120.0,

                repeats:
                    true
            ) { [weak self] _ in

                guard
                    let self = self
                else {
                    return
                }


                guard
                    self.isRunning
                else {
                    return
                }


                self.cursorWindow?
                    .updatePosition()
            }
    }


    // ========================================================
    // HIDE REAL MACOS CURSOR
    // ========================================================

    private func hideSystemCursor() {

        guard
            !isCursorHidden
        else {
            return
        }


        isCursorHidden =
            true


        NSCursor.hide()


        CGDisplayHideCursor(
            CGMainDisplayID()
        )
    }


    // ========================================================
    // SHOW REAL MACOS CURSOR
    // ========================================================

    private func showSystemCursor() {

        guard
            isCursorHidden
        else {
            return
        }


        isCursorHidden =
            false


        NSCursor.unhide()


        CGDisplayShowCursor(
            CGMainDisplayID()
        )
    }


    // ========================================================
    // BACKGROUND WATCHDOG
    // ========================================================

    private func startCursorWatchdog() {

        hideTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    0.15,

                repeats:
                    true
            ) { [weak self] _ in

                guard
                    let self = self
                else {
                    return
                }


                guard
                    self.isRunning
                else {
                    return
                }


                // Keep WindowServer background
                // cursor hiding enabled.

                self.skyLight
                    .enableBackgroundCursorHiding()


                // Keep RGB cursor attached to mouse.

                self.cursorWindow?
                    .updatePosition()


                // Keep RGB cursor above everything.

                self.cursorWindow?
                    .orderFrontRegardless()
            }
    }


    // ========================================================
    // APP BECOMES ACTIVE
    // ========================================================

    func applicationDidBecomeActive(
        _ notification: Notification
    ) {

        guard
            isRunning
        else {
            return
        }


        skyLight
            .enableBackgroundCursorHiding()


        hideSystemCursor()


        cursorWindow?
            .orderFrontRegardless()
    }


    // ========================================================
    // APP LOSES FOCUS
    // ========================================================

    func applicationDidResignActive(
        _ notification: Notification
    ) {

        guard
            isRunning
        else {
            return
        }


        // This is important because another app
        // is now in the foreground.

        skyLight
            .enableBackgroundCursorHiding()


        hideSystemCursor()


        cursorWindow?
            .orderFrontRegardless()
    }


    // ========================================================
    // QUIT
    // ========================================================

    @objc private func quitApp() {

        positionTimer?
            .invalidate()


        hideTimer?
            .invalidate()


        // Always restore the real cursor.

        showSystemCursor()


        cursorWindow?
            .close()


        NSApp.terminate(nil)
    }


    // ========================================================
    // APP TERMINATION
    // ========================================================

    func applicationWillTerminate(
        _ notification: Notification
    ) {

        positionTimer?
            .invalidate()


        hideTimer?
            .invalidate()


        showSystemCursor()
    }
}


// ============================================================
// START APPLICATION
// ============================================================

let app =
    NSApplication.shared


let delegate =
    AppDelegate()


app.delegate =
    delegate


// Menu-bar application only.

app.setActivationPolicy(
    .accessory
)


app.run()
