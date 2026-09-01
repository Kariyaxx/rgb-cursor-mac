import Cocoa
import QuartzCore

// MARK: - RGB Cursor

final class CursorView: NSView {
    
    private var hue: CGFloat = 0
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        
        let size: CGFloat = 32
        
        // Keep the cursor small
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        
        // RGB color
        let color = NSColor(
            hue: hue / 360.0,
            saturation: 1.0,
            brightness: 1.0,
            alpha: 1.0
        )
        
        // Small Windows-style arrow
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
        
        // White cursor body
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
        
        // Don't block clicks
        ignoresMouseEvents = true
        
        // Keep the cursor above normal windows
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
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
        
        // Hide the normal cursor
        CGDisplayHideCursor(CGMainDisplayID())
        
        // Start RGB animation
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.04,
            repeats: true
        ) { [weak self] _ in
            self?.updateCursor()
        }
        
        updateCursor()
    }
    
    
    private func updateCursor() {
        
        cursorView.updateHue()
        
        let mouse = NSEvent.mouseLocation
        
        // Position the cursor so the tip is where the real mouse is
        let x = mouse.x - 5
        let y = mouse.y - 27
        
        cursorWindow.setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )
    }
    
    
    func applicationWillTerminate(_ notification: Notification) {
        restoreCursor()
    }
    
    
    private func restoreCursor() {
        CGDisplayShowCursor(CGMainDisplayID())
    }
}


// MARK: - Start Application

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()