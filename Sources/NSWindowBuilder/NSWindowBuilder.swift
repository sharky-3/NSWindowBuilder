import AppKit
import SwiftUI

@MainActor
private final class HoverableWindow: NSWindow {

    var onHover: ((Bool) -> Void)?
    var expandedSize: CGSize = CGSize(width: 300, height: 60)
    var collapsedSize: CGSize = CGSize(width: 250, height: 38)

    private var trackingArea: NSTrackingArea?

    func setupTrackingArea() {
        guard let contentView else {
            return
        }

        if let trackingArea {
            contentView.removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )

        contentView.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)

        animateToSize(expandedSize)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)

        animateToSize(collapsedSize)
    }

    private func animateToSize(_ newSize: CGSize) {
        var frame = self.frame

        let oldWidth = frame.width
        let oldHeight = frame.height

        frame.size = newSize

        frame.origin.x += (oldWidth - newSize.width) / 2
        frame.origin.y += (oldHeight - newSize.height)

        animator().setFrame(frame, display: true)
    }
}

@MainActor
public struct NSWindowBuilder {

    public var size: CGSize
    public var collapsedSize: CGSize
    public var alignment: Alignment
    public var xOffset: CGFloat
    public var yOffset: CGFloat

    public var level: NSWindow.Level
    public var ignoresMouseEvents: Bool
    public var hasShadow: Bool
    public var backgroundColor: NSColor
    public var isOpaque: Bool

    public var collectionBehavior: NSWindow.CollectionBehavior
    public var styleMask: NSWindow.StyleMask

    public var onHover: ((Bool) -> Void)?

    public init(
        size: CGSize = CGSize(width: 300, height: 60),
        collapsedSize: CGSize = CGSize(width: 250, height: 38),
        alignment: Alignment = .center,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        level: NSWindow.Level = .screenSaver,
        ignoresMouseEvents: Bool = false,
        hasShadow: Bool = false,
        backgroundColor: NSColor = .clear,
        isOpaque: Bool = false,
        collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ],
        styleMask: NSWindow.StyleMask = [.borderless],
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.size = size
        self.collapsedSize = collapsedSize
        self.alignment = alignment
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.level = level
        self.ignoresMouseEvents = ignoresMouseEvents
        self.hasShadow = hasShadow
        self.backgroundColor = backgroundColor
        self.isOpaque = isOpaque
        self.collectionBehavior = collectionBehavior
        self.styleMask = styleMask
        self.onHover = onHover
    }

    public func newWindow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> NSWindow {

        guard let screen = NSScreen.main else {
            fatalError("No screen available")
        }

        let x = screen.frame.midX
            - collapsedSize.width / 2
            + xOffset

        let y = screen.frame.maxY
            - collapsedSize.height
            + yOffset

        let hostingView = NSHostingView(
            rootView: content()
                .frame(
                    width: size.width,
                    height: size.height,
                    alignment: alignment
                )
        )

        let window = HoverableWindow(
            contentRect: CGRect(
                x: x,
                y: y,
                width: collapsedSize.width,
                height: collapsedSize.height
            ),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView

        window.isOpaque = isOpaque
        window.backgroundColor = backgroundColor
        window.level = level
        window.ignoresMouseEvents = ignoresMouseEvents
        window.collectionBehavior = collectionBehavior
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.hasShadow = hasShadow

        window.onHover = onHover
        window.expandedSize = size
        window.collapsedSize = collapsedSize

        window.setupTrackingArea()
        window.orderFront(nil)

        return window
    }
}
