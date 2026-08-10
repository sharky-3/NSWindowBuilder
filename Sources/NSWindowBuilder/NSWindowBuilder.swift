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

        guard let screen = NSScreen.main else {
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

        let hostingView = NSHostingView(
            rootView: HoverWindowContent(
                window: window,
                collapsedSize: collapsedSize,
                expandedSize: size,
                xOffset: xOffset,
                yOffset: yOffset,
                alignment: alignment,
                content: content()
            )
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

        window.orderFront(nil)

        return window
    }
}

private struct HoverWindowContent<Content: View>: View {

    let window: NSWindow
    let collapsedSize: CGSize
    let expandedSize: CGSize
    let xOffset: CGFloat
    let yOffset: CGFloat
    let alignment: Alignment
    let content: Content

    @State private var isHovered = false

    var body: some View {
        content
            .frame(
                width: isHovered
                    ? expandedSize.width
                    : collapsedSize.width,
                height: isHovered
                    ? expandedSize.height
                    : collapsedSize.height,
                alignment: alignment
            )
            .onHover { hovering in
                guard hovering != isHovered else {
                    return
                }

                isHovered = hovering

                resizeWindow(
                    to: hovering
                        ? expandedSize
                        : collapsedSize
                )
            }
    }

    private func resizeWindow(to size: CGSize) {
        guard let screen = NSScreen.main else {
            return
        }

        let newX = screen.frame.midX
            - size.width / 2
            + xOffset

        let newY = screen.frame.maxY
            - size.height
            + yOffset

        let newFrame = CGRect(
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
                newFrame,
                display: true
            )
        }
    }
}
