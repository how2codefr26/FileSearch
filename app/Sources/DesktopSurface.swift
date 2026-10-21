import AppKit

/// Keep AppKit's search/editor geometry, omitting only the outer opaque bezel.
final class DesktopSearchCell:NSSearchFieldCell {
    override func draw(withFrame cellFrame:NSRect,in controlView:NSView){
        super.drawInterior(withFrame:cellFrame,in:controlView)
    }
}

/// Background transparency is independent of foreground content.
final class DesktopSurface:NSView {
    let glass=NSVisualEffectView()
    private var solid=false
    override var isOpaque:Bool {false}
    override init(frame:NSRect){
        super.init(frame:frame)
        wantsLayer=true;layer?.cornerRadius=12;layer?.masksToBounds=true
        glass.frame=bounds;glass.autoresizingMask=[.width,.height]
        glass.material = .hudWindow;glass.blendingMode = .behindWindow;glass.state = .active
        addSubview(glass)
    }
    required init?(coder:NSCoder){fatalError()}
    func configure(opacity:Double,glass:Bool,reduceTransparency:Bool){
        solid = !glass || reduceTransparency
        self.glass.isHidden=solid
        self.glass.alphaValue=opacity
        refreshColor()
    }
    private func refreshColor(){effectiveAppearance.performAsCurrentDrawingAppearance{layer?.backgroundColor=(solid ? NSColor.windowBackgroundColor:NSColor.clear).cgColor}}
    override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();refreshColor()}
}

/// A translucent darker layer, never an opaque system control bezel.
final class DesktopShade:NSView {
    let shade:CGFloat
    init(frame:NSRect,shade:CGFloat=0.12,radius:CGFloat=6){
        self.shade=shade;super.init(frame:frame);wantsLayer=true
        layer?.cornerRadius=radius;layer?.backgroundColor=NSColor.black.withAlphaComponent(shade).cgColor
    }
    required init?(coder:NSCoder){fatalError()}
    override var mouseDownCanMoveWindow:Bool {true}
}

func desktopPlate(_ control:NSView)->NSView {
    let plate=DesktopShade(frame:.zero)
    plate.addSubview(control);control.translatesAutoresizingMaskIntoConstraints=false
    NSLayoutConstraint.activate([
        control.leadingAnchor.constraint(equalTo:plate.leadingAnchor,constant:6),
        control.trailingAnchor.constraint(equalTo:plate.trailingAnchor,constant:-6),
        control.topAnchor.constraint(equalTo:plate.topAnchor,constant:2),
        control.bottomAnchor.constraint(equalTo:plate.bottomAnchor,constant:-2)
    ])
    return plate
}
