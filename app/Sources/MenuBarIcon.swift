import AppKit

enum MenuBarIcon {
    // A small, purpose-drawn folder-and-lens emblem, tinted by macOS as a template.
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let folder = NSBezierPath()
            folder.lineWidth = 1.5
            folder.lineCapStyle = .round
            folder.lineJoinStyle = .round
            folder.move(to: NSPoint(x: 7, y: 4))
            for point in [NSPoint(x: 2, y: 4), NSPoint(x: 2, y: 14),
                          NSPoint(x: 6, y: 14), NSPoint(x: 8, y: 12),
                          NSPoint(x: 14, y: 12), NSPoint(x: 14, y: 11)] {
                folder.line(to: point)
            }
            folder.stroke()
            let lens = NSBezierPath(ovalIn: NSRect(x: 8.2, y: 4.1, width: 6.4, height: 6.4))
            lens.lineWidth = 1.5
            lens.stroke()
            let handle = NSBezierPath()
            handle.lineWidth = 1.7
            handle.lineCapStyle = .round
            handle.move(to: NSPoint(x: 13.8, y: 4.9))
            handle.line(to: NSPoint(x: 16.2, y: 2.5))
            handle.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = tr("文件搜索")
        return image
    }
}
