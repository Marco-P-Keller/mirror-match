import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }

// background
let bg = CGGradient(colorsSpace: cs, colors: [c(0.14, 0.08, 0.32), c(0.03, 0.03, 0.09)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: CGFloat(S)), end: CGPoint(x: CGFloat(S), y: 0), options: [])
for (col, p) in [(c(1, 0.27, 0.75), CGPoint(x: 900, y: 900)), (c(0.25, 0.9, 1), CGPoint(x: 100, y: 120))] {
    let rg = CGGradient(colorsSpace: cs, colors: [col.copy(alpha: 0.28)!, col.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(rg, startCenter: p, startRadius: 0, endCenter: p, endRadius: 700, options: [])
}

let r: CGFloat = 250
let cy = CGFloat(S) / 2
let leftC = CGPoint(x: 512 - 128, y: cy)
let rightC = CGPoint(x: 512 + 128, y: cy)
func circle(_ p: CGPoint, _ rad: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2), transform: nil) }

// lens (intersection)
ctx.saveGState()
ctx.addPath(circle(leftC, r)); ctx.clip()
ctx.addPath(circle(rightC, r)); ctx.clip()
let lens = CGGradient(colorsSpace: cs, colors: [c(1, 1, 1, 0.95), c(0.85, 0.95, 1, 0.85)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(lens, start: CGPoint(x: 512, y: cy + r), end: CGPoint(x: 512, y: cy - r), options: [])
ctx.restoreGState()

// rings with glow
func ring(_ p: CGPoint, _ col: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 50, color: col)
    ctx.setStrokeColor(col)
    ctx.setLineWidth(58)
    ctx.addPath(circle(p, r)); ctx.strokePath()
    ctx.restoreGState()
    ctx.setStrokeColor(col)
    ctx.setLineWidth(58)
    ctx.addPath(circle(p, r)); ctx.strokePath()
}
ring(leftC, c(0.25, 0.9, 1))
ring(rightC, c(1, 0.27, 0.75))

// mirror axis highlight
ctx.setStrokeColor(c(1, 1, 1, 0.9))
ctx.setLineWidth(14); ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 512, y: cy - 150)); ctx.addLine(to: CGPoint(x: 512, y: cy + 150)); ctx.strokePath()

let img = ctx.makeImage()!
let out = CommandLine.arguments[1]
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
