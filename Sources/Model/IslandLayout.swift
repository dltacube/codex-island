import Foundation

struct IslandLayout: Equatable {
    let size: CGSize
    var horizontalOffset: CGFloat = 0

    func rect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.midX - size.width / 2 + horizontalOffset,
            y: bounds.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
