import SwiftUI

// MARK: - Icon Types

enum AiraIconType {
    case new, script, live, collection, star, recent, settings
    case sidebar, back, forward
    case trash, edit, save, notch
}

// MARK: - Animated Icon View

/// SVG-style icon with Claude-style spring bounce on hover.
/// All paths drawn in a 24×24 coordinate space, scaled to `size`.
struct AiraIcon: View {
    let type: AiraIconType
    var size: CGFloat = 22
    var color: Color = .primary
    var animated: Bool = true   // set false for toolbar/utility icons
    var filled: Bool = false    // fill the shape instead of stroking (star only for now)

    @State private var isHovered = false

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 24.0
            let stroke = StrokeStyle(lineWidth: 2.5 * s, lineCap: .round, lineJoin: .round)
            let thin   = StrokeStyle(lineWidth: 2.0 * s, lineCap: .round, lineJoin: .round)

            // Helpers
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func rc(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }

            switch type {

            // MARK: New (+)
            case .new:
                var p = Path()
                p.move(to: pt(12, 6));  p.addLine(to: pt(12, 18))
                p.move(to: pt(6, 12));  p.addLine(to: pt(18, 12))
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Script (document with scribble lines)
            case .script:
                var page = Path()
                page.move(to: pt(6, 3))
                page.addLine(to: pt(15, 3))
                page.addLine(to: pt(19, 7))
                page.addLine(to: pt(19, 21))
                page.addQuadCurve(to: pt(17, 23), control: pt(19, 23))
                page.addLine(to: pt(7, 23))
                page.addQuadCurve(to: pt(5, 21), control: pt(5, 23))
                page.addLine(to: pt(5, 5))
                page.addQuadCurve(to: pt(6, 3), control: pt(5, 4))
                page.closeSubpath()
                page.move(to: pt(15, 3))
                page.addLine(to: pt(15, 7))
                page.addLine(to: pt(19, 7))
                context.stroke(page, with: .color(color), style: stroke)

                var scribble = Path()
                scribble.move(to: pt(8, 10)); scribble.addQuadCurve(to: pt(15.5, 10), control: pt(11.5, 9))
                scribble.move(to: pt(8, 13)); scribble.addQuadCurve(to: pt(16, 13), control: pt(12, 14))
                scribble.move(to: pt(8, 16)); scribble.addQuadCurve(to: pt(14, 16), control: pt(11, 15.3))
                context.stroke(scribble, with: .color(color.opacity(0.9)), style: thin)

            // MARK: Live (broadcast)
            case .live:
                context.stroke(Path(ellipseIn: rc(9, 9, 6, 6)), with: .color(color), style: stroke)
                var w = Path()
                w.move(to: pt(7, 7))
                w.addQuadCurve(to: pt(5, 12), control: pt(5, 9))
                w.addQuadCurve(to: pt(7, 17), control: pt(5, 15))
                w.move(to: pt(17, 7))
                w.addQuadCurve(to: pt(19, 12), control: pt(19, 9))
                w.addQuadCurve(to: pt(17, 17), control: pt(19, 15))
                context.stroke(w, with: .color(color), style: stroke)
                var ow = Path()
                ow.move(to: pt(4, 4))
                ow.addQuadCurve(to: pt(2, 12), control: pt(2, 6))
                ow.addQuadCurve(to: pt(4, 20), control: pt(2, 18))
                ow.move(to: pt(20, 4))
                ow.addQuadCurve(to: pt(22, 12), control: pt(22, 6))
                ow.addQuadCurve(to: pt(20, 20), control: pt(22, 18))
                context.stroke(ow, with: .color(color.opacity(0.4)), style: thin)

            // MARK: Collection (folder)
            case .collection:
                var p = Path()
                p.move(to: pt(3, 6))
                p.addLine(to: pt(3, 18))
                p.addCurve(to: pt(5, 20), control1: pt(3, 19), control2: pt(4, 20))
                p.addLine(to: pt(19, 20))
                p.addCurve(to: pt(21, 18), control1: pt(20, 20), control2: pt(21, 19))
                p.addLine(to: pt(21, 8))
                p.addCurve(to: pt(19, 6), control1: pt(21, 7), control2: pt(20, 6))
                p.addLine(to: pt(13, 6))
                p.addLine(to: pt(11, 4))
                p.addLine(to: pt(5, 4))
                p.addCurve(to: pt(3, 6), control1: pt(4, 4), control2: pt(3, 5))
                p.closeSubpath()
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Star
            case .star:
                var p = Path()
                let pts: [(CGFloat, CGFloat)] = [
                    (12,3),(14,9),(20,10),(16,14),(17,20),(12,17),(7,20),(8,14),(4,10),(10,9)
                ]
                p.move(to: pt(pts[0].0, pts[0].1))
                pts.dropFirst().forEach { p.addLine(to: pt($0.0, $0.1)) }
                p.closeSubpath()
                if filled {
                    context.fill(p, with: .color(color))
                } else {
                    context.stroke(p, with: .color(color), style: stroke)
                }

            // MARK: Recent (clock)
            case .recent:
                context.stroke(Path(ellipseIn: rc(3.5, 3.5, 17, 17)), with: .color(color), style: stroke)
                var h = Path()
                h.move(to: pt(12, 7)); h.addLine(to: pt(12, 12)); h.addLine(to: pt(15.5, 14))
                context.stroke(h, with: .color(color), style: stroke)

            // MARK: Settings (gear)
            case .settings:
                context.stroke(Path(ellipseIn: rc(9, 9, 6, 6)), with: .color(color), style: stroke)
                var sp = Path()
                let spokes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (12,2,12,5),(12,19,12,22),(4.9,4.9,7.05,7.05),(16.95,16.95,19.1,19.1),
                    (2,12,5,12),(19,12,22,12),(4.9,19.1,7.05,16.95),(16.95,7.05,19.1,4.9)
                ]
                spokes.forEach { sp.move(to: pt($0.0,$0.1)); sp.addLine(to: pt($0.2,$0.3)) }
                context.stroke(sp, with: .color(color), style: stroke)

            // MARK: Sidebar toggle
            case .sidebar:
                let outer = Path(roundedRect: rc(3, 5, 18, 14), cornerRadius: 2 * s)
                context.stroke(outer, with: .color(color), style: thin)
                context.fill(Path(roundedRect: rc(3, 5, 6, 14), cornerRadius: 2 * s),
                             with: .color(color.opacity(0.3)))
                var dv = Path()
                dv.move(to: pt(9, 5)); dv.addLine(to: pt(9, 19))
                context.stroke(dv, with: .color(color), style: thin)

            // MARK: Back chevron
            case .back:
                var p = Path()
                p.move(to: pt(15, 18)); p.addLine(to: pt(9, 12)); p.addLine(to: pt(15, 6))
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Forward chevron
            case .forward:
                var p = Path()
                p.move(to: pt(9, 18)); p.addLine(to: pt(15, 12)); p.addLine(to: pt(9, 6))
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Trash
            case .trash:
                var p = Path()
                p.move(to: pt(5, 7));  p.addLine(to: pt(5, 21))
                p.addLine(to: pt(19, 21)); p.addLine(to: pt(19, 7))
                p.move(to: pt(9, 3));  p.addLine(to: pt(15, 3))
                p.move(to: pt(3, 7));  p.addLine(to: pt(21, 7))
                p.move(to: pt(10, 11)); p.addLine(to: pt(10, 17))
                p.move(to: pt(14, 11)); p.addLine(to: pt(14, 17))
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Edit (pencil)
            case .edit:
                var p = Path()
                p.move(to: pt(18, 3)); p.addLine(to: pt(21, 6))
                p.addLine(to: pt(9, 18)); p.addLine(to: pt(3, 20))
                p.addLine(to: pt(5, 14)); p.closeSubpath()
                p.move(to: pt(15, 6)); p.addLine(to: pt(18, 9))
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Save (floppy)
            case .save:
                var p = Path()
                p.move(to: pt(19, 21))
                p.addLine(to: pt(5, 21))
                p.addQuadCurve(to: pt(3, 19), control: pt(3, 21))
                p.addLine(to: pt(3, 5))
                p.addQuadCurve(to: pt(5, 3), control: pt(3, 3))
                p.addLine(to: pt(16, 3))
                p.addLine(to: pt(21, 8))
                p.addLine(to: pt(21, 19))
                p.addQuadCurve(to: pt(19, 21), control: pt(21, 21))
                p.move(to: pt(8, 3))
                p.addLine(to: pt(8, 8))
                p.addLine(to: pt(16, 8))
                p.move(to: pt(12, 11))
                p.addLine(to: pt(12, 21))
                context.stroke(p, with: .color(color), style: stroke)

            // MARK: Notch
            case .notch:
                var p = Path()
                p.move(to: pt(2, 8))
                p.addLine(to: pt(2, 16))
                p.addLine(to: pt(8, 16))
                p.addLine(to: pt(10, 20))
                p.addLine(to: pt(14, 20))
                p.addLine(to: pt(16, 16))
                p.addLine(to: pt(22, 16))
                p.addLine(to: pt(22, 8))
                p.closeSubpath()
                p.move(to: pt(8, 12))
                p.addLine(to: pt(16, 12))
                context.stroke(p, with: .color(color), style: stroke)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(animated && isHovered ? 1.15 : 1.0)
        .rotationEffect(animated && isHovered ? .degrees(-5) : .degrees(0))
        .shadow(
            color: .black.opacity(animated && isHovered ? 0.15 : 0),
            radius: animated && isHovered ? 5 : 0,
            y: animated && isHovered ? 3 : 0
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.5, blendDuration: 0), value: isHovered)
        .onHover { if animated { isHovered = $0 } }
    }
}
