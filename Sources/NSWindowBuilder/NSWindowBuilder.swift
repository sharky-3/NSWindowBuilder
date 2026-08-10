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

        let coordinator = WindowCoordinator(
            collapsedSize: collapsedSize,
            expandedSize: size,
            alignment: alignment,
            xOffset: xOffset,
            yOffset: yOffset,
            level: level,
            ignoresMouseEvents: ignoresMouseEvents,
            hasShadow: hasShadow,
            backgroundColor: backgroundColor,
            isOpaque: isOpaque,
            collectionBehavior: collectionBehavior,
            styleMask: styleMask,
            screen: screen,
            content: content()
        )

        coordinator.show()

        coordinator.visualWindow.delegate = coordinator

        return coordinator.visualWindow
    }
}

@MainActor
private final class WindowCoordinator<Content: View>: NSObject, NSWindowDelegate {

    let collapsedSize: CGSize
    let expandedSize: CGSize
    let alignment: Alignment
    let xOffset: CGFloat
    let yOffset: CGFloat

    let level: NSWindow.Level
    let ignoresMouseEvents: Bool
    let hasShadow: Bool
    let backgroundColor: NSColor
    let isOpaque: Bool

    let collectionBehavior: NSWindow.CollectionBehavior
    let styleMask: NSWindow.StyleMask
    let screen: NSScreen
    let content: Content

    let visualWindow: NSWindow
    let hitWindow: NSWindow

    init(
        collapsedSize: CGSize,
        expandedSize: CGSize,
        alignment: Alignment,
        xOffset: CGFloat,
        yOffset: CGFloat,
        level: NSWindow.Level,
        ignoresMouseEvents: Bool,
        hasShadow: Bool,
        backgroundColor: NSColor,
        isOpaque: Bool,
        collectionBehavior: NSWindow.CollectionBehavior,
        styleMask: NSWindow.StyleMask,
        screen: NSScreen,
        content: Content
    ) {
        self.collapsedSize = collapsedSize
        self.expandedSize = expandedSize
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
        self.screen = screen
        self.content = content

        let initialFrame = Self.frame(
            size: collapsedSize,
            screen: screen,
            xOffset: xOffset,
            yOffset: yOffset
        )
        
        self.visualWindow = NSWindow(
            contentRect: initialFrame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(
            rootView: content
                .frame(
                    width: expandedSize.width,
                    height: expandedSize.height,
                    alignment: alignment
                )
        )

        self.visualWindow.contentView = hostingView

        self.visualWindow.isOpaque = isOpaque
        self.visualWindow.backgroundColor = backgroundColor
        self.visualWindow.level = level
        self.visualWindow.ignoresMouseEvents = true
        self.visualWindow.collectionBehavior = collectionBehavior
        self.visualWindow.titlebarAppearsTransparent = true
        self.visualWindow.titleVisibility = .hidden
        self.visualWindow.hasShadow = hasShadow

        self.hitWindow = NSWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let tracker = HoverTrackerView(
            size: collapsedSize
        )

        self.hitWindow.contentView = tracker

        self.hitWindow.isOpaque = false
        self.hitWindow.backgroundColor = .clear
        self.hitWindow.hasShadow = false
        self.hitWindow.level = level
        self.hitWindow.ignoresMouseEvents = ignoresMouseEvents
        self.hitWindow.collectionBehavior = collectionBehavior

        super.init()

        tracker.onHoverChanged = { [weak self] hovering in
            guard let self else {
                return
            }

            self.setExpanded(hovering)
        }
    }

    func show() {
        visualWindow.orderFront(nil)
        hitWindow.orderFront(nil)
    }

    private func setExpanded(_ expanded: Bool) {

        let targetSize = expanded
            ? expandedSize
            : collapsedSize

        let targetFrame = Self.frame(
            size: targetSize,
            screen: screen,
            xOffset: xOffset,
            yOffset: yOffset
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(
                name: .easeInEaseOut
            )

            visualWindow.animator().setFrame(
                targetFrame,
                display: true
            )
        }
    }

    static func frame(
        size: CGSize,
        screen: NSScreen,
        xOffset: CGFloat,
        yOffset: CGFloat
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

    func windowWillClose(_ notification: Notification) {
        hitWindow.close()
    }
}

@MainActor
private final class HoverTrackerView: NSView {

    private let trackingSize: CGSize

    var onHoverChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(size: CGSize) {
        self.trackingSize = size

        super.init(
            frame: CGRect(
                origin: .zero,
                size: size
            )
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseEnteredAndExited,
                .activeAlways
            ],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isHovering else {
            return
        }

        isHovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard isHovering else {
            return
        }

        isHovering = false
        onHoverChanged?(false)
    }
}
