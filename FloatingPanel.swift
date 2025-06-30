import Cocoa
import QuickLookThumbnailing

/// A content view that drags the window only when the background (not file items) is clicked.
private class DraggableContentView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    if let hit = super.hitTest(point), hit !== self { return hit }
    return self
  }
  override func mouseDown(with event: NSEvent) {
    window?.performDrag(with: event)
  }
}

/// A stack view which lets its arranged subviews handle clicks first.
private class PassthroughStackView: NSStackView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    let local = convert(point, from: superview)
    for sub in arrangedSubviews.reversed() {
      let child = sub.convert(local, from: self)
      if let hit = sub.hitTest(child) { return hit }
    }
    return nil
  }
}

class FloatingPanel: NSPanel, NSDraggingDestination {
  
  // MARK: - Animated Hover Button
  private class HoverButton: NSButton {
    private var hoverArea: NSTrackingArea?
    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      if let area = hoverArea {
        removeTrackingArea(area)
      }
      let area = NSTrackingArea(rect: bounds,
                                options: [.mouseEnteredAndExited, .activeAlways],
                                owner: self,
                                userInfo: nil)
      addTrackingArea(area)
      hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) {
      guard let layer = self.layer else { return }
      CATransaction.begin()
      CATransaction.setAnimationDuration(0.2)
      layer.backgroundColor = NSColor(red: 0.95, green: 0.33, blue: 0.22, alpha: 1.0).cgColor
      layer.borderColor = NSColor(red: 0.95, green: 0.33, blue: 0.22, alpha: 1.0).cgColor
      CATransaction.commit()
    }
    override func mouseExited(with event: NSEvent) {
      guard let layer = self.layer else { return }
      CATransaction.begin()
      CATransaction.setAnimationDuration(0.2)
      layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
      layer.borderColor = NSColor.separatorColor.cgColor
      CATransaction.commit()
    }
  }

  private var fileItems: [URL] = []
  private let stackView = PassthroughStackView()
  private let originalSize: NSSize = NSSize(width: 200, height: 200)

  init() {
    // 1) Size & center
    let screen = NSScreen.main?.visibleFrame
      ?? NSRect(x: 200, y: 200, width: 400, height: 400)
    let side: CGFloat = 200
    let origin = NSPoint(x: screen.midX - side/2, y: screen.midY - side/2)
    let frame = NSRect(origin: origin, size: NSSize(width: side, height: side))

    super.init(contentRect: frame,
               styleMask: .borderless,
               backing: .buffered,
               defer: false)

    // 2) Keep on top and drag background manually
    hidesOnDeactivate = false
    level = .floating
    isFloatingPanel = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = false

    // 3) Dark semi-transparent look
    isOpaque = false
    backgroundColor = .clear
    contentView = DraggableContentView()
    contentView?.wantsLayer = true
    contentView?.layer?.cornerRadius = 12
    contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

    setupUI()
    registerForDraggedTypes([.fileURL])
    orderFrontRegardless()
      
    // Lock the panel to its initial square size
    self.minSize = frame.size
    self.maxSize = frame.size
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  // MARK: - Animations
  func animateIn() {
    alphaValue = 0
    orderFrontRegardless()
    animator().alphaValue = 1
    animator().setFrame(frame.insetBy(dx: -10, dy: -10), display: true)
  }

  func animateOut() {
    animator().alphaValue = 0
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      self.orderOut(nil)
      self.alphaValue = 1
    }
  }

  private func updateWindowLevel() {
    if fileItems.isEmpty {
      level = .floating
    } else {
      let top = CGWindowLevelForKey(.screenSaverWindow)
      level = NSWindow.Level(rawValue: Int(top))
      orderFrontRegardless()
    }
  }

  @objc private func closePanel(_ _: Any) { close() }
    
    /// Combines clear-all + close into one button action
    @objc private func closeAndClear(_ sender: Any) {
      clearAll(sender)
      closePanel(sender)
    }

  
  @objc private func clearAll(_ _: Any) {
    fileItems.removeAll()
    stackView.arrangedSubviews.forEach {
      stackView.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }
    updateWindowLevel()
    
    // Reset window to original size
    resetToOriginalSize()
  }
  
  private func resetToOriginalSize() {
    // Temporarily unlock size constraints
    minSize = NSSize(width: 100, height: 100)
    maxSize = NSSize(width: 10000, height: 10000)
    
    // Calculate new frame with same center point
    let currentCenter = NSPoint(
      x: frame.midX,
      y: frame.midY
    )
    
    let newOrigin = NSPoint(
      x: currentCenter.x - originalSize.width / 2,
      y: currentCenter.y - originalSize.height / 2
    )
    
    let newFrame = NSRect(origin: newOrigin, size: originalSize)
    
    // Animate the resize
    animator().setFrame(newFrame, display: true)
    
    // Re-lock the size after animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      self.minSize = self.originalSize
      self.maxSize = self.originalSize
    }
  }

      // MARK: - Border Animation
    private func animateBorder(highlight: Bool) {
        guard let layer = contentView?.layer else { return }
        let newWidth: CGFloat = highlight ? 4 : 0
        // make it a CGColor in both branches
        let newColor = highlight
            ? NSColor(red: 0.95, green: 0.33, blue: 0.22, alpha: 1.0).cgColor
            : NSColor.clear.cgColor

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        layer.borderWidth = newWidth
        layer.borderColor = newColor
        CATransaction.commit()
    }

    // Ensure border resets when drag exits
    func draggingExited(_ sender: NSDraggingInfo?) {
        animateBorder(highlight: false)
    }

    // MARK: - UI Setup
    private func setupUI() {
    guard let cv = contentView else { return }

    // Drag strip
    let dragArea = NSView(); dragArea.translatesAutoresizingMaskIntoConstraints = false
    cv.addSubview(dragArea)
    dragArea.addGestureRecognizer(NSPanGestureRecognizer(
      target: self, action: #selector(handleWindowDrag(_:))
      
      
    
    ))

    // Close button
        

        

    let closeBtn = HoverButton()
    closeBtn.isBordered = false
    closeBtn.translatesAutoresizingMaskIntoConstraints = false
    closeBtn.target = self; closeBtn.action = #selector(closeAndClear(_:))
    closeBtn.wantsLayer = true; closeBtn.layer?.cornerRadius = 6
    closeBtn.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    closeBtn.layer?.borderWidth = 1
    closeBtn.layer?.borderColor = NSColor.separatorColor.cgColor
    closeBtn.controlSize = .small
    if #available(macOS 11.0, *) {
      let img = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)!
      img.isTemplate = true; closeBtn.image = img
      closeBtn.contentTintColor = .labelColor
    } else {
      closeBtn.title = "×"; closeBtn.font = .systemFont(ofSize: 14, weight: .bold)
    }
    cv.addSubview(closeBtn)

    // File list stack
    stackView.orientation = .vertical
    stackView.spacing = 8
    stackView.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    cv.addSubview(stackView)

    // Clear All
    let clearBtn = HoverButton(title: "Clear All", target: self, action: #selector(clearAll(_:)))
    clearBtn.bezelStyle = .texturedRounded
    clearBtn.controlSize = .small
    clearBtn.font = .systemFont(ofSize: 11)
    clearBtn.wantsLayer = true
    clearBtn.layer?.cornerRadius = 6
    clearBtn.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    clearBtn.layer?.borderWidth = 1
    clearBtn.layer?.borderColor = NSColor.separatorColor.cgColor
    clearBtn.translatesAutoresizingMaskIntoConstraints = false
    cv.addSubview(clearBtn)
        
    NSLayoutConstraint.activate([
      dragArea.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
      dragArea.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
      dragArea.topAnchor.constraint(equalTo: cv.topAnchor),
      dragArea.heightAnchor.constraint(equalToConstant: 8),

      closeBtn.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 8),
      closeBtn.topAnchor.constraint(equalTo: dragArea.bottomAnchor, constant: 4),
      closeBtn.widthAnchor.constraint(equalToConstant: 24),
      closeBtn.heightAnchor.constraint(equalToConstant: 24),

      stackView.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
      stackView.topAnchor.constraint(equalTo: closeBtn.bottomAnchor, constant: 4),
      stackView.bottomAnchor.constraint(equalTo: clearBtn.topAnchor, constant: -8),

      clearBtn.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
      clearBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -8),
      clearBtn.heightAnchor.constraint(equalToConstant: 24),
    ])
  }

    // MARK: - Drag & Drop
  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    animateBorder(highlight: true)
    return .copy
  }

    func draggingEnded(_ sender: NSDraggingInfo) {
    animateBorder(highlight: false)
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    animateBorder(highlight: false)
    guard let urls = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: nil)
          as? [URL]
    else { return false }

    for url in urls {
      // Very simple duplicate check - just compare file names and sizes
      let isDuplicate = fileItems.contains { existingURL in
        // Compare filename and file size for basic duplicate detection
        guard url.lastPathComponent == existingURL.lastPathComponent else { return false }
        
        do {
          let attr1 = try FileManager.default.attributesOfItem(atPath: url.path)
          let attr2 = try FileManager.default.attributesOfItem(atPath: existingURL.path)
          let size1 = attr1[.size] as? Int64 ?? 0
          let size2 = attr2[.size] as? Int64 ?? 0
          return size1 == size2
        } catch {
          // If we can't get sizes, just compare names
          return true
        }
      }
      
      if !isDuplicate {
        fileItems.append(url)
        let item = FileItemView(fileURL: url)
        stackView.addArrangedSubview(item)
        updateWindowLevel()
      }
    }
    return true
  }

  // MARK: - Window Drag
    // MARK: - Window Drag
    @objc private func handleWindowDrag(_ gr: NSPanGestureRecognizer) {
    guard gr.state == .began, let ev = NSApp.currentEvent else { return }
    performDrag(with: ev)
  }
}

