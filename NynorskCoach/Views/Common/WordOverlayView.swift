import SwiftUI

/// Overlay view to display recognized words with tap handling
struct WordOverlayView: View {
    let words: [RecognizedWord]
    let imageSize: CGSize
    let containerSize: CGSize
    let onWordTap: (String) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let fitSize = calculateFitSize(imageSize: imageSize, containerSize: geo.size)
            let xOffset = (geo.size.width - fitSize.width) / 2
            let yOffset = (geo.size.height - fitSize.height) / 2
            
            ZStack(alignment: .topLeading) {
                ForEach(words) { word in
                    let rect = convertRect(word.boundingBox, viewSize: fitSize)
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.blue, lineWidth: 1)
                        .background(Color.blue.opacity(0.1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: xOffset + rect.midX, y: yOffset + rect.midY)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let localX = location.x - xOffset
                let localY = location.y - yOffset
                
                if let hit = words.first(where: { word in
                    let rect = convertRect(word.boundingBox, viewSize: fitSize)
                    let standardRect = CGRect(
                        x: rect.midX - rect.width / 2,
                        y: rect.midY - rect.height / 2,
                        width: rect.width,
                        height: rect.height
                    )
                    return standardRect.contains(CGPoint(x: localX, y: localY))
                }) {
                    onWordTap(hit.text)
                }
            }
        }
    }
    
    func convertRect(_ rect: CGRect, viewSize: CGSize) -> CGRect {
        let width = rect.width * viewSize.width
        let height = rect.height * viewSize.height
        let x = rect.minX * viewSize.width
        let y = (1 - rect.maxY) * viewSize.height
        return CGRect(x: x + width / 2, y: y + height / 2, width: width, height: height)
    }
    
    func calculateFitSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        if imageSize.width == 0 || imageSize.height == 0 { return .zero }
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }
}
