import AVFoundation
import UIKit
import SwiftUI

/// Renders a vertical (9:16) replay clip of a match locally, ready for TikTok / Reels / Stories.
enum ReplayRenderer {
    static let W = 720
    static let H = 1280
    static let fps = 30

    struct Spec {
        var records: [RoundRecord]
        var names: [String]        // [you] or [you, opponent]
        var skinColors: [UIColor]
        var headline: String
        var subline: String
        var cta: String
    }

    static func render(records: [RoundRecord], names: [String], skin: Skin, headline: String, subline: String, cta: String = "Think you can beat me?") async throws -> URL {
        let spec = Spec(records: records, names: names, skinColors: skin.colors.map { UIColor($0) }, headline: headline, subline: subline, cta: cta)
        return try await Task.detached(priority: .userInitiated) { try renderSync(spec) }.value
    }

    private static let introLen = 1.0
    private static let roundLen = 2.6
    private static let outroLen = 2.0

    private static func renderSync(_ s: Spec) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MirrorMatch-Replay-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: W, AVVideoHeightKey: H,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 5_000_000]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H
        ])
        guard writer.canAdd(input) else { throw NSError(domain: "Replay", code: 1) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "Replay", code: 2) }
        writer.startSession(atSourceTime: .zero)

        let totalSeconds = introLen + Double(s.records.count) * roundLen + outroLen
        let frames = Int(totalSeconds * Double(fps))
        let cs = CGColorSpaceCreateDeviceRGB()

        for f in 0..<frames {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.004) }
            guard let pool = adaptor.pixelBufferPool else { throw NSError(domain: "Replay", code: 3) }
            var pbOut: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
            guard let pb = pbOut else { throw NSError(domain: "Replay", code: 4) }
            CVPixelBufferLockBaseAddress(pb, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                ctx.translateBy(x: 0, y: CGFloat(H))
                ctx.scaleBy(x: 1, y: -1)
                UIGraphicsPushContext(ctx)
                drawFrame(ctx, spec: s, t: Double(f) / Double(fps))
                UIGraphicsPopContext()
            }
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()
        if writer.status != .completed { throw writer.error ?? NSError(domain: "Replay", code: 5) }
        return url
    }

    // MARK: drawing
    private static let cyan = UIColor(red: 0.25, green: 0.9, blue: 1, alpha: 1)
    private static let magenta = UIColor(red: 1, green: 0.27, blue: 0.75, alpha: 1)
    private static let lime = UIColor(red: 0.6, green: 1, blue: 0.4, alpha: 1)

    private static func font(_ size: CGFloat, _ w: UIFont.Weight = .heavy) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: w)
        if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return base
    }

    private static func text(_ str: String, _ rect: CGRect, size: CGFloat, color: UIColor = .white, weight: UIFont.Weight = .heavy, align: NSTextAlignment = .center) {
        let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byTruncatingTail
        (str as NSString).draw(in: rect, withAttributes: [.font: font(size, weight), .foregroundColor: color, .paragraphStyle: p])
    }

    private static func background(_ ctx: CGContext) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: cs, colors: [UIColor(red: 0.09, green: 0.06, blue: 0.2, alpha: 1).cgColor, UIColor(red: 0.027, green: 0.027, blue: 0.07, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: H), options: [])
        for (c, p) in [(magenta, CGPoint(x: W, y: 0)), (cyan, CGPoint(x: 0, y: H))] {
            let rg = CGGradient(colorsSpace: cs, colors: [c.withAlphaComponent(0.22).cgColor, c.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(rg, startCenter: p, startRadius: 0, endCenter: p, endRadius: 600, options: [])
        }
    }

    private static func drawFrame(_ ctx: CGContext, spec: Spec, t: Double) {
        background(ctx)
        // watermark
        text("MIRROR MATCH", CGRect(x: 0, y: 34, width: W, height: 40), size: 28, color: .white.withAlphaComponent(0.85))
        if t < introLen {
            let a = min(1, t / 0.4)
            text(spec.headline, CGRect(x: 40, y: 480, width: W - 80, height: 120), size: 70, color: cyan.withAlphaComponent(a))
            text(spec.subline, CGRect(x: 40, y: 610, width: W - 80, height: 60), size: 36, weight: .semibold)
            return
        }
        let afterIntro = t - introLen
        let roundsEnd = Double(spec.records.count) * roundLen
        if afterIntro < roundsEnd {
            let idx = min(spec.records.count - 1, Int(afterIntro / roundLen))
            let lt = afterIntro - Double(idx) * roundLen
            drawRound(ctx, spec: spec, idx: idx, t: lt)
        } else {
            drawOutro(ctx, spec: spec, t: afterIntro - roundsEnd)
        }
    }

    private static func drawRound(_ ctx: CGContext, spec: Spec, idx: Int, t: Double) {
        let rec = spec.records[idx]
        let two = rec.results.count > 1
        text("ROUND \(idx + 1)", CGRect(x: 0, y: 92, width: W, height: 50), size: 40, color: cyan)
        text(rec.move.title.uppercased() + (rec.move.mirrored ? " · MIRRORED" : ""), CGRect(x: 0, y: 140, width: W, height: 40), size: 26, color: .white.withAlphaComponent(0.7), weight: .semibold)

        let drawP = max(0, min(1, (t - 0.5) / 1.2))
        let showScore = t > 1.7
        let colorsYou = spec.skinColors
        let colorsOpp = [UIColor.white, UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 1)]

        if two {
            let a = CGRect(x: 120, y: 200, width: 480, height: 480)
            let b = CGRect(x: 120, y: 720, width: 480, height: 480)
            panel(ctx, rect: a, move: rec.move, result: rec.results[1], progress: drawP, colors: colorsOpp, label: spec.names.count > 1 ? spec.names[1] : "Rival", score: showScore ? rec.results[1].score : nil, win: rec.results[1].score > rec.results[0].score)
            panel(ctx, rect: b, move: rec.move, result: rec.results[0], progress: drawP, colors: colorsYou, label: spec.names[0], score: showScore ? rec.results[0].score : nil, win: rec.results[0].score >= rec.results[1].score)
        } else {
            let a = CGRect(x: 40, y: 260, width: 640, height: 640)
            panel(ctx, rect: a, move: rec.move, result: rec.results[0], progress: drawP, colors: colorsYou, label: spec.names[0], score: showScore ? rec.results[0].score : nil, win: rec.results[0].score >= 70)
        }
    }

    private static func panel(_ ctx: CGContext, rect: CGRect, move: Move, result: RoundResult, progress: Double, colors: [UIColor], label: String, score: Int?, win: Bool) {
        let rr = UIBezierPath(roundedRect: rect, cornerRadius: 36)
        UIColor.white.withAlphaComponent(0.06).setFill(); rr.fill()
        (win && score != nil ? lime : UIColor.white.withAlphaComponent(0.18)).setStroke()
        rr.lineWidth = win && score != nil ? 5 : 2; rr.stroke()

        func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height) }

        // target (dashed)
        UIColor.white.withAlphaComponent(0.35).setStroke()
        switch move.kind {
        case .path:
            let d = UIBezierPath()
            for (i, p) in move.target.enumerated() { i == 0 ? d.move(to: pt(p)) : d.addLine(to: pt(p)) }
            d.lineWidth = 5; d.lineCapStyle = .round; d.setLineDash([2, 12], count: 2, phase: 0); d.stroke()
            strokeTrail(ctx, pts: result.path.map(pt), progress: progress, colors: colors, width: 12)
        case .taps:
            for (i, p) in move.target.enumerated() {
                let c = pt(p)
                let ring = UIBezierPath(ovalIn: CGRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60))
                ring.lineWidth = 4; ring.stroke()
                text("\(i + 1)", CGRect(x: c.x - 30, y: c.y - 16, width: 60, height: 34), size: 26, color: UIColor.white.withAlphaComponent(0.5))
            }
            let shown = Int(progress * Double(result.path.count) + 0.999)
            for (i, p) in result.path.prefix(shown).enumerated() {
                let c = pt(p)
                colors[i % colors.count].setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32)).fill()
            }
        case .pinch:
            let v = 1 + (result.pinchValue - 1) * progress
            text(String(format: "×%.1f", v), CGRect(x: rect.minX, y: rect.midY - 50, width: rect.width, height: 100), size: 80, color: colors[0])
            text(String(format: "target ×%.1f", move.pinchScale), CGRect(x: rect.minX, y: rect.midY + 40, width: rect.width, height: 40), size: 26, color: .white.withAlphaComponent(0.5), weight: .semibold)
        }
        text(label, CGRect(x: rect.minX + 20, y: rect.minY + 14, width: rect.width * 0.55, height: 34), size: 24, color: .white.withAlphaComponent(0.8), align: .left)
        if let score {
            text("\(score)", CGRect(x: rect.maxX - 170, y: rect.minY + 8, width: 150, height: 70), size: 58, color: win ? lime : .white, align: .right)
        }
    }

    private static func strokeTrail(_ ctx: CGContext, pts: [CGPoint], progress: Double, colors: [UIColor], width: CGFloat) {
        let n = max(0, Int(progress * Double(pts.count)))
        guard n > 1 else { return }
        let step = max(1, n / 120)
        ctx.setLineCap(.round)
        var k = step
        while k < n {
            let tt = Double(k) / Double(max(1, pts.count))
            let col = lerp(colors, tt)
            ctx.setShadow(offset: .zero, blur: 16, color: col.withAlphaComponent(0.9).cgColor)
            ctx.setStrokeColor(col.cgColor)
            ctx.setLineWidth(width)
            ctx.move(to: pts[k - step]); ctx.addLine(to: pts[k]); ctx.strokePath()
            k += step
        }
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        let head = pts[n - 1]
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: head.x - 11, y: head.y - 11, width: 22, height: 22)).fill()
    }

    private static func lerp(_ colors: [UIColor], _ t: Double) -> UIColor {
        guard colors.count > 1 else { return colors.first ?? .white }
        let x = max(0, min(0.9999, t)) * Double(colors.count - 1)
        let i = Int(x); let f = CGFloat(x - Double(i))
        var a: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0), b: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        colors[i].getRed(&a.0, green: &a.1, blue: &a.2, alpha: &a.3)
        colors[i + 1].getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
        return UIColor(red: a.0 + (b.0 - a.0) * f, green: a.1 + (b.1 - a.1) * f, blue: a.2 + (b.2 - a.2) * f, alpha: 1)
    }

    private static func drawOutro(_ ctx: CGContext, spec: Spec, t: Double) {
        let pop = min(1, t / 0.35)
        text(spec.headline, CGRect(x: 30, y: 430, width: W - 60, height: 130), size: 84 * (0.8 + 0.2 * pop), color: lime)
        text(spec.subline, CGRect(x: 30, y: 575, width: W - 60, height: 60), size: 40, weight: .bold)
        text(spec.cta, CGRect(x: 30, y: 760, width: W - 60, height: 60), size: 38, color: cyan)
        let pill = UIBezierPath(roundedRect: CGRect(x: 160, y: 850, width: 400, height: 84), cornerRadius: 42)
        magenta.setFill(); pill.fill()
        text("Get Mirror Match", CGRect(x: 160, y: 868, width: 400, height: 50), size: 34, color: .black)
        text("on the App Store", CGRect(x: 0, y: 960, width: W, height: 40), size: 26, color: .white.withAlphaComponent(0.6), weight: .semibold)
    }
}
