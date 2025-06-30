import Cocoa
import QuickLookThumbnailing

/// Shows a QuickLook thumbnail and lets you drag the file out.
class FileItemView: NSView, NSDraggingSource {
  private let fileURL: URL
  private let imageView = NSImageView()
  private let textField: NSTextField
  private var initialDragPoint: NSPoint?

  init(fileURL: URL) {
    self.fileURL = fileURL
    textField = NSTextField(labelWithString: fileURL.lastPathComponent)
    super.init(frame: .zero)

    // Register for drag and drop - but we'll be transparent to incoming drags
    // registerForDraggedTypes([.fileURL])  // Comment this out

    // Thumbnail setup
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.imageScaling = .scaleProportionallyUpOrDown

    // Label setup
    textField.lineBreakMode = .byTruncatingMiddle
    textField.font = .systemFont(ofSize: 10, weight: .medium)
    textField.translatesAutoresizingMaskIntoConstraints = false

    // Style
    wantsLayer = true
    layer?.cornerRadius = 6
    layer?.backgroundColor = NSColor.quaternaryLabelColor
                       .withAlphaComponent(0.1).cgColor

    // Layout
    let hstack = NSStackView(views: [imageView, textField])
    hstack.orientation = .horizontal
    hstack.spacing = 8
    hstack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    hstack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hstack)

    NSLayoutConstraint.activate([
      imageView.widthAnchor.constraint(equalToConstant: 32),
      imageView.heightAnchor.constraint(equalToConstant: 32),
      hstack.leadingAnchor.constraint(equalTo: leadingAnchor),
      hstack.trailingAnchor.constraint(equalTo: trailingAnchor),
      hstack.topAnchor.constraint(equalTo: topAnchor),
      hstack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    // QuickLook thumbnail
    let size = CGSize(width: 32, height: 32)
    let scale = NSScreen.main?.backingScaleFactor ?? 1
    let req = QLThumbnailGenerator.Request(
      fileAt: fileURL,
      size: size,
      scale: scale,
      representationTypes: .thumbnail
    )
    QLThumbnailGenerator.shared
      .generateBestRepresentation(for: req) { [weak self] thumb, _ in
        DispatchQueue.main.async {
          guard let self = self else { return }
          if let cg = thumb?.cgImage {
            self.imageView.image = NSImage(cgImage: cg, size: size)
          } else {
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = size
            self.imageView.image = icon
          }
        }
      }
  }

  required init?(coder: NSCoder) { fatalError() }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  
  override func hitTest(_ point: NSPoint) -> NSView? {
    return bounds.contains(point) ? self : nil
  }

  // Override these methods to explicitly NOT handle drops - let them pass through
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return []  // Don't accept any drops
  }
  
  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    return []  // Don't accept any drops
  }

  override func mouseDown(with event: NSEvent) {
    initialDragPoint = convert(event.locationInWindow, from: nil)
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start = initialDragPoint else { return }
    let loc = convert(event.locationInWindow, from: nil)
    if hypot(loc.x - start.x, loc.y - start.y) < 3 { return }

    let pb = fileURL as NSURL
    let dragItem = NSDraggingItem(pasteboardWriter: pb)
    let img = NSImage(size: bounds.size)
    img.lockFocus()
    layer?.render(in: NSGraphicsContext.current!.cgContext)
    img.unlockFocus()
    dragItem.setDraggingFrame(bounds, contents: img)

    let session = beginDraggingSession(
      with: [dragItem],
      event: event,
      source: self
    )
    session.animatesToStartingPositionsOnCancelOrFail = true
    initialDragPoint = nil
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    return [.copy, .move]
  }


}
