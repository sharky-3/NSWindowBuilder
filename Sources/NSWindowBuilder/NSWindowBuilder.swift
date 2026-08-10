import AppKit
import SwiftUI

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

    public init(
        size: CGSize = CGSize(width: 300, height: 60),
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

        let x = screen.frame.midX
            - size.width / 2
            + xOffset

        let y = screen.frame.maxY
            - size.height
            + yOffset

        let hostingView = PassthroughHostingView(
            rootView: content()
                .frame(
                    width: size.width,
                    height: size.height,
                    alignment: alignment
                )
        )

        let window = OverlayWindow(
            contentRect: CGRect(
                x: x,
                y: y,
                width: size.width,
                height: size.height
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

        window.orderFront(nil)

        return window
    }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hitView = super.hitTest(point) else { return nil }
        
        if hitView === self { return nil }
        return hitView
    }
}
