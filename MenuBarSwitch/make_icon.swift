// 生成应用图标: 蓝色渐变圆角方块 + 白色显示器轮廓 + 双向切换箭头
// 用法: swift make_icon.swift <输出png路径(1024x1024)>

import Foundation
import CoreGraphics
import AppKit

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_1024.png"

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(S), height: Int(S),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

// 背景圆角方块 + 对角渐变
let bgPath = CGPath(
    roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
    cornerWidth: 232, cornerHeight: 232, transform: nil
)
ctx.addPath(bgPath)
ctx.clip()
let gradient = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.31, green: 0.58, blue: 1.00, alpha: 1),
        CGColor(red: 0.10, green: 0.24, blue: 0.62, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// 显示器外框（描边）
ctx.setStrokeColor(white)
ctx.setLineWidth(46)
let screen = CGPath(
    roundedRect: CGRect(x: 132, y: 262, width: 760, height: 440),
    cornerWidth: 56, cornerHeight: 56, transform: nil
)
ctx.addPath(screen)
ctx.strokePath()

// 支架
ctx.setFillColor(white)
ctx.fill(CGRect(x: 472, y: 204, width: 80, height: 58))
let base = CGPath(
    roundedRect: CGRect(x: 352, y: 164, width: 320, height: 44),
    cornerWidth: 22, cornerHeight: 22, transform: nil
)
ctx.addPath(base)
ctx.fillPath()

// 两条循环切换箭头（上：向左，下：向右）
func drawArrow(y: CGFloat, shaft: (CGFloat, CGFloat), apex: CGFloat, pointingRight: Bool) {
    let halfShaft: CGFloat = 26
    let headBase: CGFloat = 96
    let (a, b) = min(shaft.0, shaft.1) == shaft.0 ? (shaft.0, shaft.1) : (shaft.1, shaft.0)
    ctx.setFillColor(white)
    // 箭杆
    ctx.fill(CGRect(x: a, y: y - halfShaft, width: b - a, height: halfShaft * 2))
    // 箭头
    let head = CGMutablePath()
    if pointingRight {
        head.move(to: CGPoint(x: apex, y: y))
        head.addLine(to: CGPoint(x: apex - headBase, y: y + 54))
        head.addLine(to: CGPoint(x: apex - headBase, y: y - 54))
    } else {
        head.move(to: CGPoint(x: apex, y: y))
        head.addLine(to: CGPoint(x: apex + headBase, y: y - 54))
        head.addLine(to: CGPoint(x: apex + headBase, y: y + 54))
    }
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()
}

drawArrow(y: 558, shaft: (398, 700), apex: 306, pointingRight: false)
drawArrow(y: 410, shaft: (324, 626), apex: 718, pointingRight: true)

// 导出 PNG
let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("图标已生成: \(outPath)")
