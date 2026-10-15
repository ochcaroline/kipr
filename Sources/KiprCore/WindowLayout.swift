import CoreGraphics

public enum WindowOperation: String, Sendable {
    case leftHalf = "left-half", rightHalf = "right-half", topHalf = "top-half", bottomHalf = "bottom-half"
    case topLeft = "top-left", topRight = "top-right", bottomLeft = "bottom-left", bottomRight = "bottom-right"
    case maximize, center
    case nextDisplay = "next-display", previousDisplay = "previous-display"
}

public enum WindowLayout {
    /// Coordinates are top-left based. `gap` applies to screen edges and between tiles.
    public static func frame(for operation: WindowOperation, in screen: CGRect, gap: CGFloat, windowSize: CGSize) -> CGRect {
        let a = screen.insetBy(dx: gap, dy: gap)
        let w = (a.width - gap) / 2, h = (a.height - gap) / 2
        let right = a.minX + w + gap, bottom = a.minY + h + gap
        switch operation {
        case .maximize, .nextDisplay, .previousDisplay: return a
        case .leftHalf: return CGRect(x: a.minX, y: a.minY, width: w, height: a.height)
        case .rightHalf: return CGRect(x: right, y: a.minY, width: w, height: a.height)
        case .topHalf: return CGRect(x: a.minX, y: a.minY, width: a.width, height: h)
        case .bottomHalf: return CGRect(x: a.minX, y: bottom, width: a.width, height: h)
        case .topLeft: return CGRect(x: a.minX, y: a.minY, width: w, height: h)
        case .topRight: return CGRect(x: right, y: a.minY, width: w, height: h)
        case .bottomLeft: return CGRect(x: a.minX, y: bottom, width: w, height: h)
        case .bottomRight: return CGRect(x: right, y: bottom, width: w, height: h)
        case .center:
            let size = CGSize(width: min(windowSize.width, a.width), height: min(windowSize.height, a.height))
            return CGRect(x: a.midX - size.width / 2, y: a.midY - size.height / 2, width: size.width, height: size.height)
        }
    }
}
