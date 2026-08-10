import AppKit
import SwiftUI

@MainActor
private final class HoverableWindow: NSWindow {

    var onHover: ((Bool) -> Void)?
    var expandedSize: CGSize = CGSize(width: 300, height: 60)

    private let collapsedSize = CGSize(
        width: 250,
        height: 38
    )

    private var trackingArea: NSTrackingArea?
    private var isExpanded = false

    override func mouseEntered(with event: NSEvent) {
        guard !isExpanded else {
            return
        }

        isExpanded = true
        onHover?(true)
        resize(to: expandedSize)
    }

    override func mouseExited(with event: NSEvent) {
        guard isExpanded else {
            return
        }

        isExpanded = false
        onHover?(false)
        resize(to: collapsedSize)
    }

    func setupTrackingArea() {
        guard let contentView else {
            return
        }

        if let trackingArea {
            contentView.removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: contentView.bounds,
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

    private func resize(to size: CGSize) {
        let currentFrame = frame

        let newFrame = NSRect(
            x: currentFrame.midX - size.width / 2,
            y: currentFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        animator().setFrame(
            newFrame,
            display: true
        )
    }
}

@MainActor
public struct NSWindowBuilder {

    public var size: CGSize
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
        size: CGSize = CGSize(
            width: 300,
            height: 60
        ),
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
        styleMask: NSWindow.StyleMask = [
            .borderless
        ],
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.size = size
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

        let collapsedWidth: CGFloat = 250
        let collapsedHeight: CGFloat = 38

        let x = screen.frame.midX
            - collapsedWidth / 2
            + xOffset

        let y = screen.frame.maxY
            - collapsedHeight
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
            contentRect: NSRect(
                x: x,
                y: y,
                width: collapsedWidth,
                height: collapsedHeight
            ),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.expandedSize = size
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

        window.setupTrackingArea()
        window.orderFront(nil)

        return window
    }
}
