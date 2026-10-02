import SwiftUI

enum TrailDrawer {
    /// Draws a glowing, skinned trail. `pts` are normalized (0...1) in a square of `side` points.
    static func draw(_ ctx: inout GraphicsContext, pts: [CGPoint], side: CGFloat, skin: Skin, width: CGFloat = 9, opacity: Double = 1, head: Bool = true) {
        guard pts.count > 1 else {
            if let p = pts.first, head { drawHead(&ctx, at: CGPoint(x: p.x * side, y: p.y * side), skin: skin, opacity: opacity) }
            return
        }
        let step = max(1, pts.count / 140)
        var idx = Array(stride(from: 0, to: pts.count, by: step))
        if idx.last != pts.count - 1 { idx.append(pts.count - 1) }
        let n = Double(idx.count)

        func seg(_ a: Int, _ b: Int) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: pts[a].x * side, y: pts[a].y * side))
            path.addLine(to: CGPoint(x: pts[b].x * side, y: pts[b].y * side))
            return path
        }
        func color(_ k: Int) -> Color {
            let t = Double(k) / n
            return skin.style == .rainbow ? skin.color(at: (t * 2).truncatingRemainder(dividingBy: 1)) : skin.color(at: t)
        }

        // glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: width * 0.9))
            for k in 1..<idx.count {
                l.stroke(seg(idx[k - 1], idx[k]), with: .color(color(k).opacity(0.7 * opacity)), style: StrokeStyle(lineWidth: width * 1.9, lineCap: .round))
            }
        }
        // core
        if skin.style == .dots {
            for k in 0..<idx.count where k % 2 == 0 {
                let p = pts[idx[k]]
                let r = width * 0.55
                ctx.fill(Path(ellipseIn: CGRect(x: p.x * side - r, y: p.y * side - r, width: r * 2, height: r * 2)), with: .color(color(k).opacity(opacity)))
            }
        } else {
            for k in 1..<idx.count {
                ctx.stroke(seg(idx[k - 1], idx[k]), with: .color(color(k).opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        if skin.style == .sparkle {
            for k in stride(from: 2, to: idx.count, by: 3) {
                let p = pts[idx[k]]
                let h1 = sin(Double(k) * 12.9898) * 43758.5453
                let h2 = sin(Double(k) * 78.233) * 12543.123
                let dx = (h1 - h1.rounded(.down) - 0.5) * width * 3
                let dy = (h2 - h2.rounded(.down) - 0.5) * width * 3
                let r = width * (0.18 + 0.2 * (h1 - h1.rounded(.down)))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x * side + dx - r, y: p.y * side + dy - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(0.8 * opacity)))
            }
        }
        if head, let last = pts.last {
            drawHead(&ctx, at: CGPoint(x: last.x * side, y: last.y * side), skin: skin, opacity: opacity)
        }
    }

    static func drawHead(_ ctx: inout GraphicsContext, at p: CGPoint, skin: Skin, opacity: Double = 1) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 9))
            l.fill(Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36)), with: .color(skin.colors.last!.opacity(0.8 * opacity)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(.white.opacity(opacity)))
        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(skin.head.opacity(opacity)), lineWidth: 3)
    }

    static func dashed(_ ctx: inout GraphicsContext, pts: [CGPoint], side: CGFloat, color: Color = .white.opacity(0.4)) {
        guard pts.count > 1 else { return }
        var path = Path()
        path.move(to: CGPoint(x: pts[0].x * side, y: pts[0].y * side))
        for p in pts.dropFirst() { path.addLine(to: CGPoint(x: p.x * side, y: p.y * side)) }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 9]))
    }

    static func tapMarker(_ ctx: inout GraphicsContext, at p: CGPoint, side: CGFloat, number: Int, skin: Skin, filled: Bool = false, scale: Double = 1, opacity: Double = 1) {
        let c = CGPoint(x: p.x * side, y: p.y * side)
        let r = 22 * scale
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 8))
            l.fill(Path(ellipseIn: rect), with: .color(skin.color(at: Double(number) / 5).opacity(0.55 * opacity)))
        }
        ctx.fill(Path(ellipseIn: rect), with: .color(filled ? skin.color(at: Double(number) / 5).opacity(opacity) : Color.black.opacity(0.45 * opacity)))
        ctx.stroke(Path(ellipseIn: rect), with: .color(skin.color(at: Double(number) / 5).opacity(opacity)), lineWidth: 3)
        ctx.draw(Text("\(number + 1)").font(Theme.font(18)).foregroundStyle(filled ? Color.black : Color.white), at: c)
    }
}
