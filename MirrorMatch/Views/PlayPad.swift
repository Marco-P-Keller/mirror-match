import SwiftUI

enum PadMode: Equatable {
    case idle
    case demo(Date)
    case live(Date)
    case reveal
}

struct PlayPad: View {
    let move: Move
    var mode: PadMode
    var skin: Skin
    var revealResult: RoundResult? = nil
    var rival: RoundResult? = nil
    var onFinish: (PadInput) -> Void = { _ in }

    @State private var pts: [CGPoint] = []
    @State private var taps: [CGPoint] = []
    @State private var tapTimes: [Date] = []
    @State private var pinch: Double = 1
    @State private var finished = false

    private var isLive: Bool { if case .live = mode { return true } else { return false } }
    private var animating: Bool {
        switch mode { case .demo, .live: return true; default: return false }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.white.opacity(0.055))
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [skin.head.opacity(0.7), Color.white.opacity(0.08), skin.colors.last!.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                dotGrid(side: side)
                TimelineView(.animation(paused: !animating)) { tl in
                    Canvas { ctx, size in
                        drawContent(&ctx, side: side, now: tl.date)
                    }
                }
                .allowsHitTesting(false)
                if isLive && finished {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.black.opacity(0.35))
                    Label("Locked in", systemImage: "checkmark.circle.fill")
                        .font(Theme.font(20)).foregroundStyle(Theme.lime)
                }
                if !isLive { Color.clear.contentShape(Rectangle()) }
                if isLive && !finished { inputLayer(side: side) }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .task(id: mode) {
                if case .live(let go) = mode {
                    let remain = move.maxTime - Date().timeIntervalSince(go)
                    try? await Task.sleep(for: .seconds(max(0.1, remain)))
                    if !Task.isCancelled { finish(time: move.maxTime) }
                }
            }
            #if DEBUG
            .task(id: mode) {
                if case .live(let go) = mode, Autoplay.enabled {
                    if move.kind == .taps {
                        try? await Task.sleep(for: .seconds(0.6))
                        for (i, p) in move.target.enumerated() {
                            taps.append(CGPoint(x: p.x + 0.01, y: p.y - 0.01)); tapTimes.append(Date())
                            if i < move.target.count - 1 { try? await Task.sleep(for: .seconds(0.3)) }
                        }
                        finish(time: Date().timeIntervalSince(go))
                    } else {
                        await runAutoplay(go: go, setPts: { pts = $0 }, setPinch: { pinch = $0 }, finish: { finish(time: $0) })
                    }
                }
            }
            #endif
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: input
    @ViewBuilder
    private func inputLayer(side: CGFloat) -> some View {
        if case .live(let go) = mode {
            if move.kind == .pinch {
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .onChanged { v in pinch = v.magnification }
                            .onEnded { v in
                                pinch = v.magnification
                                Haptics.medium()
                                finish(time: Date().timeIntervalSince(go))
                            }
                    )
            } else {
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { v in
                                guard move.kind == .path else { return }
                                let p = CGPoint(x: v.location.x / side, y: v.location.y / side)
                                if pts.isEmpty { Haptics.tap() }
                                if let last = pts.last, hypot(p.x - last.x, p.y - last.y) < 0.004 { return }
                                pts.append(p)
                            }
                            .onEnded { v in
                                let p = CGPoint(x: v.location.x / side, y: v.location.y / side)
                                if move.kind == .path {
                                    if pts.count < 4 { pts = []; return }
                                    finish(time: Date().timeIntervalSince(go))
                                } else {
                                    taps.append(p)
                                    tapTimes.append(Date())
                                    Haptics.medium()
                                    if taps.count >= move.target.count { finish(time: Date().timeIntervalSince(go)) }
                                }
                            }
                    )
            }
        }
    }

    private func finish(time: Double) {
        guard !finished else { return }
        finished = true
        Haptics.tap()
        onFinish(PadInput(path: pts, taps: taps, pinch: pinch, time: time))
    }

    // MARK: drawing
    private func dotGrid(side: CGFloat) -> some View {
        Canvas { ctx, size in
            let n = 6
            for i in 1..<n {
                for j in 1..<n {
                    let x = size.width * CGFloat(i) / CGFloat(n), y = size.height * CGFloat(j) / CGFloat(n)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.1)))
                }
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    private func drawContent(_ ctx: inout GraphicsContext, side: CGFloat, now: Date) {
        switch mode {
        case .idle:
            break
        case .demo(let start):
            let el = max(0, now.timeIntervalSince(start))
            switch move.kind {
            case .path:
                let p = min(1, el / move.duration)
                let count = max(1, Int(p * Double(move.points.count)))
                TrailDrawer.draw(&ctx, pts: Array(move.points.prefix(count)), side: side, skin: skin)
            case .taps:
                let n = move.points.count
                let slot = (move.duration - 0.4) / Double(n)
                for (i, pt) in move.points.enumerated() {
                    let t = el - Double(i) * slot
                    if t >= 0 {
                        let pop = min(1, t / 0.18)
                        TrailDrawer.tapMarker(&ctx, at: pt, side: side, number: i, skin: skin, filled: t < 0.3, scale: 0.6 + 0.4 * pop)
                    }
                }
            case .pinch:
                drawPinch(&ctx, side: side, value: 1 + (move.pinchScale - 1) * min(1, el / move.duration))
            }
        case .live(let go):
            let el = now.timeIntervalSince(go)
            switch move.kind {
            case .path:
                if pts.isEmpty {
                    if let s = move.target.first {
                        let pulse = 1 + 0.18 * sin(el * 6)
                        let r = 15 * pulse
                        let c = CGPoint(x: s.x * side, y: s.y * side)
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(skin.head.opacity(0.9)), lineWidth: 3)
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.white))
                    }
                } else {
                    TrailDrawer.draw(&ctx, pts: pts, side: side, skin: skin)
                }
            case .taps:
                for (i, p) in taps.enumerated() {
                    let age = now.timeIntervalSince(tapTimes[i])
                    TrailDrawer.tapMarker(&ctx, at: p, side: side, number: i, skin: skin, filled: true, scale: 0.8, opacity: max(0.3, 1 - age))
                }
            case .pinch:
                drawPinch(&ctx, side: side, value: pinch)
            }
        case .reveal:
            switch move.kind {
            case .path:
                TrailDrawer.dashed(&ctx, pts: move.target, side: side)
                if let r = rival, r.path.count > 1 {
                    TrailDrawer.draw(&ctx, pts: r.path, side: side, skin: Skin.byID("ice"), width: 5, opacity: 0.45, head: false)
                }
                if let r = revealResult { TrailDrawer.draw(&ctx, pts: r.path, side: side, skin: skin, head: false) }
            case .taps:
                for (i, p) in move.target.enumerated() {
                    TrailDrawer.tapMarker(&ctx, at: p, side: side, number: i, skin: Skin.byID("ice"), scale: 0.9, opacity: 0.55)
                }
                if let r = revealResult {
                    for (i, p) in r.path.enumerated() {
                        TrailDrawer.tapMarker(&ctx, at: p, side: side, number: i, skin: skin, filled: true, scale: 0.55)
                    }
                }
            case .pinch:
                drawPinch(&ctx, side: side, value: move.pinchScale, ghost: true)
                if let r = revealResult { drawPinch(&ctx, side: side, value: r.pinchValue) }
            }
        }
    }

    private func drawPinch(_ ctx: inout GraphicsContext, side: CGFloat, value: Double, ghost: Bool = false) {
        let c = CGPoint(x: side / 2, y: side / 2)
        let d = side * 0.1 * max(0.2, min(4.2, value)) / 0.7 * 0.7
        let dx = d * 0.7071, dy = d * 0.7071
        let a = CGPoint(x: c.x - dx, y: c.y + dy), b = CGPoint(x: c.x + dx, y: c.y - dy)
        var line = Path(); line.move(to: a); line.addLine(to: b)
        let col: Color = ghost ? .white.opacity(0.4) : skin.head
        ctx.stroke(line, with: .color(col.opacity(0.6)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: ghost ? [2, 8] : []))
        for p in [a, b] {
            if !ghost { TrailDrawer.drawHead(&ctx, at: p, skin: skin) }
            else { ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)), with: .color(col), lineWidth: 3) }
        }
    }
}
