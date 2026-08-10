import AppKit
import SwiftUI

@MainActor
private final class HoverableWindow: NSWindow {

    var onHover: ((Bool) -> Void)?

    var expandedSize: CGSize
    let collapsedSize = CGSize(width: 250, height: 38)

    private var trackingTimer: Timer?
    private var hovering = false

    init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        expandedSize: CGSize
    ) {
        self.expandedSize = expandedSize

        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )

        trackingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.03,
            repeats: true
        ) { [weak self] _ in
            self?.checkHover()
        }
    }

    private func checkHover() {
        let mouse = NSEvent.mouseLocation

        let hoverRect = NSRect(
            x: frame.midX - expandedSize.width / 2,
            y: frame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )

        let isInside = hoverRect.contains(mouse)

        guard isInside != hovering else {
            return
        }

        hovering = isInside

        onHover?(isInside)

        if isInside {
            expand()
        } else {
            collapse()
        }
    }

    private func expand() {
        let currentFrame = frame

        let newFrame = NSRect(
            x: currentFrame.midX - expandedSize.width / 2,
            y: currentFrame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )

        animator().setFrame(
            newFrame,
            display: true
        )
    }

    private func collapse() {
        let currentFrame = frame

        let newFrame = NSRect(
            x: currentFrame.midX - collapsedSize.width / 2,
            y: currentFrame.maxY - collapsedSize.height,
            width: collapsedSize.width,
            height: collapsedSize.height
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

        let x = screen.frame.midX
            - 250 / 2
            + xOffset

        let y = screen.frame.maxY
            - 38
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
                width: 250,
                height: 38
            ),
            styleMask: styleMask,
            backing: .buffered,
            defer: false,
            expandedSize: size
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

        window.orderFront(nil)

        return window
    }
}
