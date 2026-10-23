// Desenha o ícone do app (1024x1024): teclado escuro com as teclas em arco-íris.
// Uso: swift scripts/make-icon.swift saida.png
import AppKit

let size: CGFloat = 1024
let rows: [[CGFloat]] = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
    [1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25],
    [2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75],
    [1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25],
]

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("uso: swift make-icon.swift saida.png\n".data(using: .utf8)!)
    exit(2)
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.14, alpha: 1).setFill()
NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185).fill()

let board = plate.insetBy(dx: 70, dy: 210)
let unit = board.width / 15
let gap = unit * 0.14
for (r, row) in rows.enumerated() {
    var x = board.minX
    let y = board.maxY - CGFloat(r + 1) * unit
    for width in row {
        let key = NSRect(x: x + gap / 2, y: y + gap / 2, width: width * unit - gap, height: unit - gap)
        let hue = (key.midX - board.minX) / board.width * 0.85
        NSColor(calibratedHue: hue, saturation: 0.75, brightness: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: key, xRadius: unit * 0.16, yRadius: unit * 0.16).fill()
        x += width * unit
    }
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("não consegui gerar o PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
