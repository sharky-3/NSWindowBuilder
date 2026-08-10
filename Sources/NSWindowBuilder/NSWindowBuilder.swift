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
        ignoresMouseEvents: Bool = true,
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
    ) -> OverlayWindow {

        guard let screen = NSScreen.main else {
            fatalError("No screen available")
        }

        let x = screen.frame.midX
            - size.width / 2
            + xOffset

        let y = screen.frame.maxY
            - size.height
            + yOffset

        let hostingView = NSHostingView(
            rootView:
                content()
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
        window.collectionBehavior = collectionBehavior

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.hasShadow = hasShadow

        window.ignoresMouseEvents = ignoresMouseEvents

        window.orderFront(nil)

        return window
    }
}


@MainActor
public final class OverlayWindow: NSWindow {
    public override var canBecomeKey: Bool {
        false
    }
    public override var canBecomeMain: Bool {
        false
    }
}

@MainActor
public final class OverlayMouseController {

    private weak var window: OverlayWindow?

    private var monitor: Any?

    public init(window: OverlayWindow) {
        self.window = window
        startMonitoring()
    }

    public func stop() {
        guard let monitor else {
            return
        }

        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func startMonitoring() {

        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [
                .mouseMoved,
                .leftMouseDown,
                .leftMouseUp,
                .rightMouseDown,
                .rightMouseUp
            ]
        ) { [weak self] _ in

            Task { @MainActor [weak self] in
                self?.update()
            }
        }
    }

    private func update() {

        guard let window else {
            return
        }

        let screenPoint = NSEvent.mouseLocation

        if !window.frame.contains(screenPoint) {
            window.ignoresMouseEvents = true
            return
        }

        guard let contentView = window.contentView else {
            window.ignoresMouseEvents = true
            return
        }

        let windowPoint = window.convertPoint(
            fromScreen: screenPoint
        )

        let localPoint = contentView.convert(
            windowPoint,
            from: nil
        )

        let hitView = contentView.hitTest(localPoint)

        if let hitView,
           hitView !== contentView {

            window.ignoresMouseEvents = false

        } else {

            window.ignoresMouseEvents = true
        }
    }
}
