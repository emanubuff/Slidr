import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingPanel?
    var statusItem: NSStatusItem!
    var shakeTimer: Timer?
    
    // Shake detection properties
    var mousePositionHistory: [NSPoint] = []
    var shakeDetectionEnabled = true
    
    // Shake parameters
    private let shakeThreshold: CGFloat = 150
    private let shakeMinDirectionChanges = 4
    private let maxHistoryPoints = 20

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.stack.3d.down.right", accessibilityDescription: "Dropover Clone")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        window = FloatingPanel()
        setupShakeDetection()
        setupStatusItemMenu()
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindowAtMouseLocation()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    private func setupStatusItemMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show/Hide Window", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Shake while dragging files", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func showWindowAtMouseLocation() {
        guard let window = window else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        var windowFrame = window.frame
        
        windowFrame.origin = NSPoint(
            x: mouseLocation.x - windowFrame.width/2,
            y: mouseLocation.y - windowFrame.height/2
        )
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            
            if windowFrame.maxX > screenFrame.maxX {
                windowFrame.origin.x = screenFrame.maxX - windowFrame.width
            }
            if windowFrame.minX < screenFrame.minX {
                windowFrame.origin.x = screenFrame.minX
            }
            
            if windowFrame.maxY > screenFrame.maxY {
                windowFrame.origin.y = screenFrame.maxY - windowFrame.height
            }
            if windowFrame.minY < screenFrame.minY {
                windowFrame.origin.y = screenFrame.minY
            }
        }
        
        window.setFrame(windowFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Shake Detection (Only During File Drag)
    private func setupShakeDetection() {
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkForShake()
        }
    }
    
    private func checkForShake() {
        // Only check for shake if we're currently dragging files
        guard isCurrentlyDraggingFiles() else {
            mousePositionHistory.removeAll() // Clear history when not dragging
            return
        }
        
        let currentMouseLocation = NSEvent.mouseLocation
        updateMouseHistory(currentMouseLocation)
        
        if shakeDetectionEnabled {
            detectShakeGesture()
        }
    }
    
    private func isCurrentlyDraggingFiles() -> Bool {
        // Check if mouse button is down (indicating a drag operation)
        let mouseDown = CGEventSource.buttonState(.hidSystemState, button: .left)
        return mouseDown
    }
    
    private func updateMouseHistory(_ location: NSPoint) {
        mousePositionHistory.append(location)
        
        if mousePositionHistory.count > maxHistoryPoints {
            mousePositionHistory.removeFirst()
        }
    }
    
    private func detectShakeGesture() {
        guard mousePositionHistory.count >= 8 else { return }
        
        let recentPositions = Array(mousePositionHistory.suffix(16))
        
        var totalDistance: CGFloat = 0
        var directionChanges = 0
        var lastDirection: CGFloat = 0
        
        for i in 1..<recentPositions.count {
            let prev = recentPositions[i-1]
            let curr = recentPositions[i]
            
            let deltaX = curr.x - prev.x
            let deltaY = curr.y - prev.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            totalDistance += distance
            
            if abs(deltaX) > 2 {
                let currentDirection: CGFloat = deltaX > 0 ? 1 : -1
                if lastDirection != 0 && currentDirection != lastDirection {
                    directionChanges += 1
                }
                lastDirection = currentDirection
            }
        }
        
        if totalDistance > shakeThreshold && directionChanges >= shakeMinDirectionChanges {
            handleShakeDetected()
        }
    }
    
    private func handleShakeDetected() {
        mousePositionHistory.removeAll()
        shakeDetectionEnabled = false
        
        showWindowAtMouseLocation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.shakeDetectionEnabled = true
        }
    }
}
