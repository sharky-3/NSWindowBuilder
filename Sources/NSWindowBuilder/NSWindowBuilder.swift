import AppKit
import SwiftUI

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
        styleMask: NSWindow.StyleMask = [.borderless]
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
    }

    public func newWindow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> NSWindow {

        // Find the screen containing the mouse.
        let mouseLocation = NSEvent.mouseLocation

        guard let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.screens.first else {
            fatalError("No screen available")
        }

        let initialSize = collapsedSize

        let x = screen.frame.midX
            - initialSize.width / 2
            + xOffset

        let y = screen.frame.maxY
            - initialSize.height
            + yOffset

        let window = NSWindow(
            contentRect: CGRect(
                x: x,
                y: y,
                width: initialSize.width,
                height: initialSize.height
            ),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        let trackingView = HoverTrackingView(
            collapsedSize: collapsedSize,
            expandedSize: size,
            xOffset: xOffset,
            yOffset: yOffset
        )

        trackingView.onHoverChanged = { [weak window] hovering in
            guard let window else { return }

            resize(
                window: window,
                screen: screen,
                size: hovering ? size : collapsedSize,
                xOffset: xOffset,
                yOffset: yOffset
            )
        }

        let hostingView = NSHostingView(
            rootView: content()
                .frame(
                    width: size.width,
                    height: size.height,
                    alignment: alignment
                )
        )

        trackingView.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(
                equalTo: trackingView.centerXAnchor
            ),
            hostingView.centerYAnchor.constraint(
                equalTo: trackingView.centerYAnchor
            )
        ])

        window.contentView = trackingView

        window.isOpaque = isOpaque
        window.backgroundColor = backgroundColor
        window.level = level
        window.ignoresMouseEvents = ignoresMouseEvents
        window.collectionBehavior = collectionBehavior

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.hasShadow = hasShadow

        window.orderFront(nil)

        return window
    }

    private func resize(
        window: NSWindow,
        screen: NSScreen,
        size: CGSize,
        xOffset: CGFloat,
        yOffset: CGFloat
    ) {
        let newX = screen.frame.midX
            - size.width / 2
            + xOffset

        let newY = screen.frame.maxY
            - size.height
            + yOffset

        let frame = CGRect(
            x: newX,
            y: newY,
            width: size.width,
            height: size.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(
                name: .easeInEaseOut
            )

            window.animator().setFrame(
                frame,
                display: true
            )
        }
    }
}


// MARK: - Hover Tracking

private final class HoverTrackingView: NSView {

    let collapsedSize: CGSize
    let expandedSize: CGSize
    let xOffset: CGFloat
    let yOffset: CGFloat

    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(
        collapsedSize: CGSize,
        expandedSize: CGSize,
        xOffset: CGFloat,
        yOffset: CGFloat
    ) {
        self.collapsedSize = collapsedSize
        self.expandedSize = expandedSize
        self.xOffset = xOffset
        self.yOffset = yOffset

        super.init(frame: .zero)

        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        // IMPORTANT:
        // Track only the collapsed-size area.
        let rect = CGRect(
            x: (bounds.width - collapsedSize.width) / 2,
            y: (bounds.height - collapsedSize.height) / 2,
            width: collapsedSize.width,
            height: collapsedSize.height
        )

        let area = NSTrackingArea(
            rect: rect,
            options: [
                .mouseEnteredAndExited,
                .activeAlways
            ],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(
        with event: NSEvent
    ) {
        guard !isHovering else { return }

        isHovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(
        with event: NSEvent
    ) {
        guard isHovering else { return }

        isHovering = false
        onHoverChanged?(false)
    }
}
