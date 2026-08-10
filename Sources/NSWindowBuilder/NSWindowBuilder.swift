import AppKit
import SwiftUI

@MainActor
public final class NSWindowBuilder {

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

    @discardableResult
    public func newWindow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> NSWindow {

        let mouseLocation = NSEvent.mouseLocation

        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(mouseLocation)
        }) else {
            fatalError("Could not determine screen")
        }

        // ---------------------------------------------------------
        // Visual window
        // ---------------------------------------------------------

        let visualFrame = frame(
            for: collapsedSize,
            on: screen
        )

        let visualWindow = NSWindow(
            contentRect: visualFrame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(
            rootView:
                content()
                    .frame(
                        width: size.width,
                        height: size.height,
                        alignment: alignment
                    )
        )

        visualWindow.contentView = hostingView

        visualWindow.isOpaque = isOpaque
        visualWindow.backgroundColor = backgroundColor
        visualWindow.level = level

        // The visual window MUST NOT receive mouse events.
        visualWindow.ignoresMouseEvents = true

        visualWindow.collectionBehavior = collectionBehavior
        visualWindow.titlebarAppearsTransparent = true
        visualWindow.titleVisibility = .hidden
        visualWindow.hasShadow = hasShadow

        // ---------------------------------------------------------
        // Hit window
        // ---------------------------------------------------------

        let hitFrame = frame(
            for: collapsedSize,
            on: screen
        )

        let hitWindow = NSWindow(
            contentRect: hitFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let tracker = HoverTrackerView(
            size: collapsedSize
        )

        tracker.onHoverChanged = { [weak self, weak visualWindow] hovering in
            guard
                let self,
                let visualWindow
            else {
                return
            }

            self.setExpanded(
                hovering,
                window: visualWindow,
                screen: screen
            )
        }

        hitWindow.contentView = tracker

        hitWindow.isOpaque = false
        hitWindow.backgroundColor = .clear
        hitWindow.hasShadow = false
        hitWindow.level = level

        // This is the ONLY window receiving mouse events.
        hitWindow.ignoresMouseEvents = ignoresMouseEvents

        hitWindow.collectionBehavior = collectionBehavior

        // Keep a strong reference to the hit window.
        objc_setAssociatedObject(
            visualWindow,
            &AssociatedKeys.hitWindow,
            hitWindow,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        // Keep the visual window alive through the hit window.
        objc_setAssociatedObject(
            hitWindow,
            &AssociatedKeys.visualWindow,
            visualWindow,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        visualWindow.orderFront(nil)
        hitWindow.orderFront(nil)

        return visualWindow
    }

    private func setExpanded(
        _ expanded: Bool,
        window: NSWindow,
        screen: NSScreen
    ) {
        let targetSize = expanded
            ? size
            : collapsedSize

        let targetFrame = frame(
            for: targetSize,
            on: screen
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(
                name: .easeInEaseOut
            )

            window.animator().setFrame(
                targetFrame,
                display: true
            )
        }
    }

    private func frame(
        for size: CGSize,
        on screen: NSScreen
    ) -> CGRect {

        CGRect(
            x: screen.frame.midX
                - size.width / 2
                + xOffset,

            y: screen.frame.maxY
                - size.height
                + yOffset,

            width: size.width,
            height: size.height
        )
    }
}


// MARK: - Hover Tracker

private final class HoverTrackerView: NSView {

    private let trackingSize: CGSize

    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var hovering = false

    init(size: CGSize) {
        self.trackingSize = size

        super.init(frame: CGRect(
            origin: .zero,
            size: size
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
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

    override func mouseEntered(with event: NSEvent) {
        guard !hovering else {
            return
        }

        hovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard hovering else {
            return
        }

        hovering = false
        onHoverChanged?(false)
    }
}


// MARK: - Associated Objects

private enum AssociatedKeys {

    static var hitWindow = "NSWindowBuilder.hitWindow"
    static var visualWindow = "NSWindowBuilder.visualWindow"
}
