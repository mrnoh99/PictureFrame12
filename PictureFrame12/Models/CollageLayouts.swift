import CoreGraphics

struct CollageTemplate {
    let cells: [CGRect]
    var count: Int { cells.count }
}

enum CollageLayouts {
    static func templates(for count: Int) -> [CollageTemplate] {
        switch count {
        case 1:  return [CollageTemplate(cells: [r(0,0,1,1)])]
        case 2:  return two
        case 3:  return three
        case 4:  return four
        case 5:  return five
        case 6:  return six
        default: return [grid(count)]
        }
    }

    static func template(count: Int, variant: Int) -> CollageTemplate {
        let list = templates(for: count)
        guard !list.isEmpty else { return grid(count) }
        let idx = ((variant % list.count) + list.count) % list.count
        return list[idx]
    }

    private static func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    private static let two: [CollageTemplate] = [
        CollageTemplate(cells: [r(0,0,0.5,1), r(0.5,0,0.5,1)]),
        CollageTemplate(cells: [r(0,0,1,0.5), r(0,0.5,1,0.5)]),
        CollageTemplate(cells: [r(0,0,0.62,1), r(0.62,0,0.38,1)]),
        CollageTemplate(cells: [r(0,0,1,0.62), r(0,0.62,1,0.38)])
    ]

    private static let three: [CollageTemplate] = [
        CollageTemplate(cells: [r(0,0,0.6,1), r(0.6,0,0.4,0.5), r(0.6,0.5,0.4,0.5)]),
        CollageTemplate(cells: [r(0,0,0.4,0.5), r(0,0.5,0.4,0.5), r(0.4,0,0.6,1)]),
        CollageTemplate(cells: [r(0,0,1,0.55), r(0,0.55,0.5,0.45), r(0.5,0.55,0.5,0.45)]),
        CollageTemplate(cells: [r(0,0,0.34,1), r(0.34,0,0.33,1), r(0.67,0,0.33,1)]),
        CollageTemplate(cells: [r(0,0,0.25,1), r(0.25,0,0.5,1), r(0.75,0,0.25,1)]),
        CollageTemplate(cells: [r(0,0,1,0.34), r(0,0.34,1,0.33), r(0,0.67,1,0.33)])
    ]

    private static let four: [CollageTemplate] = [
        CollageTemplate(cells: [r(0,0,0.5,0.5), r(0.5,0,0.5,0.5), r(0,0.5,0.5,0.5), r(0.5,0.5,0.5,0.5)]),
        CollageTemplate(cells: [r(0,0,0.55,1), r(0.55,0,0.45,0.34), r(0.55,0.34,0.45,0.33), r(0.55,0.67,0.45,0.33)]),
        CollageTemplate(cells: [r(0,0,1,0.5), r(0,0.5,0.34,0.5), r(0.34,0.5,0.33,0.5), r(0.67,0.5,0.33,0.5)]),
        CollageTemplate(cells: [r(0,0,0.6,0.5), r(0.6,0,0.4,0.6), r(0,0.5,0.4,0.5), r(0.4,0.6,0.6,0.4)]),
        CollageTemplate(cells: [r(0,0,0.25,1), r(0.25,0,0.25,1), r(0.5,0,0.25,1), r(0.75,0,0.25,1)])
    ]

    private static let five: [CollageTemplate] = [
        CollageTemplate(cells: [r(0,0,0.5,1), r(0.5,0,0.25,0.5), r(0.75,0,0.25,0.5), r(0.5,0.5,0.25,0.5), r(0.75,0.5,0.25,0.5)]),
        CollageTemplate(cells: [r(0,0,0.5,0.5), r(0.5,0,0.5,0.5), r(0,0.5,0.34,0.5), r(0.34,0.5,0.33,0.5), r(0.67,0.5,0.33,0.5)]),
        CollageTemplate(cells: [r(0.25,0.2,0.5,0.6), r(0,0,0.25,0.5), r(0.75,0,0.25,0.5), r(0,0.5,0.25,0.5), r(0.75,0.5,0.25,0.5)]),
        CollageTemplate(cells: [r(0,0,0.34,0.5), r(0.34,0,0.33,0.5), r(0.67,0,0.33,0.5), r(0,0.5,0.5,0.5), r(0.5,0.5,0.5,0.5)])
    ]

    private static let six: [CollageTemplate] = [
        CollageTemplate(cells: [r(0,0,0.34,0.5), r(0.34,0,0.33,0.5), r(0.67,0,0.33,0.5), r(0,0.5,0.34,0.5), r(0.34,0.5,0.33,0.5), r(0.67,0.5,0.33,0.5)]),
        CollageTemplate(cells: [r(0,0,0.5,1), r(0.5,0,0.5,0.34), r(0.5,0.34,0.25,0.33), r(0.75,0.34,0.25,0.33), r(0.5,0.67,0.25,0.33), r(0.75,0.67,0.25,0.33)]),
        CollageTemplate(cells: [r(0,0,0.5,0.5), r(0.5,0,0.5,0.5), r(0,0.5,0.25,0.5), r(0.25,0.5,0.25,0.5), r(0.5,0.5,0.25,0.5), r(0.75,0.5,0.25,0.5)])
    ]

    static func justified(aspects: [CGFloat], in size: CGSize, spacing: CGFloat) -> [CGRect] {
        let n = aspects.count
        guard n > 0, size.width > 1, size.height > 1 else { return [] }
        let rowsGuess = max(1, Int(Double(n).squareRoot().rounded()))
        let targetRowHeight = size.height / CGFloat(rowsGuess)
        var rows: [[Int]] = []
        var current: [Int] = []
        var aspectSum: CGFloat = 0
        for i in 0..<n {
            current.append(i)
            aspectSum += max(aspects[i], 0.05)
            let naturalWidth = aspectSum * targetRowHeight + spacing * CGFloat(current.count - 1)
            if naturalWidth >= size.width { rows.append(current); current = []; aspectSum = 0 }
        }
        if !current.isEmpty { rows.append(current) }
        var rowHeights: [CGFloat] = []
        for row in rows {
            let sum = row.reduce(CGFloat(0)) { $0 + max(aspects[$1], 0.05) }
            let totalSpacing = spacing * CGFloat(row.count - 1)
            rowHeights.append((size.width - totalSpacing) / max(sum, 0.05))
        }
        let totalH = rowHeights.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let scale = totalH > size.height ? size.height / totalH : 1.0
        let offsetY = (size.height - totalH * scale) / 2
        var rects = [CGRect](repeating: .zero, count: n)
        var y = offsetY
        for (ri, row) in rows.enumerated() {
            let h = rowHeights[ri] * scale
            let rowWidth = size.width * scale
            var x = (size.width - rowWidth) / 2
            for idx in row {
                let w = max(aspects[idx], 0.05) * h
                rects[idx] = CGRect(x: x, y: y, width: w, height: h)
                x += w + spacing * scale
            }
            y += h + spacing * scale
        }
        return rects
    }

    static func grid(_ count: Int) -> CollageTemplate {
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cw = 1.0 / CGFloat(cols)
        let ch = 1.0 / CGFloat(rows)
        var cells: [CGRect] = []
        for i in 0..<count {
            let col = i % cols; let row = i / cols
            cells.append(CGRect(x: CGFloat(col)*cw, y: CGFloat(row)*ch, width: cw, height: ch))
        }
        return CollageTemplate(cells: cells)
    }
}
