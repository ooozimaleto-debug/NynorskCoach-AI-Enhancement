import SwiftUI
import SwiftData

/// Overlay that draws colour-coded word boxes on a freeze-frame scan image
/// and forwards tap events to the parent.
///
/// Colour convention (mirrors app vocabulary states):
///   nil / unknown   →  red     (not in dictionary)
///   .new            →  red     (added, not yet studied)
///   .learning       →  yellow  (active SRS rotation)
///   .mastered       →  hidden  (user knows it — no box shown)
struct WordOverlayView: View {

    let words: [RecognizedWord]
    let imageSize: CGSize
    let savedItems: [LearningItem]   // replaces unused containerSize param
    let onWordTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let fitSize = fitImageSize(in: geo.size)
            let xOff = (geo.size.width  - fitSize.width)  / 2
            let yOff = (geo.size.height - fitSize.height) / 2

            ZStack(alignment: .topLeading) {
                ForEach(words) { word in
                    let rect  = convertRect(word.boundingBox, into: fitSize)
                    let color = strokeColor(for: lookupStatus(word.text))

                    if color != .clear {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(color, lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color.opacity(0.12))
                            )
                            .frame(width: rect.width, height: rect.height)
                            // position() centres the view at the given point,
                            // rect.midX/midY are correct because rect has a
                            // standard top-left origin (see convertRect below).
                            .position(x: xOff + rect.midX, y: yOff + rect.midY)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let local = CGPoint(x: location.x - xOff, y: location.y - yOff)
                if let hit = words.first(where: {
                    convertRect($0.boundingBox, into: fitSize).contains(local)
                }) {
                    onWordTap(hit.text)
                }
            }
        }
    }

    // MARK: – Coordinate conversion

    /// Converts a Vision normalised rect (origin bottom-left, 0…1)
    /// to a SwiftUI rect with a standard **top-left origin** scaled to `size`.
    ///
    /// BUG FIX: the old version added width/2 and height/2 to the origin,
    /// making origin equal to the center — then rect.midX overshot by another
    /// half-width, shifting every box to the right by its own half-width.
    private func convertRect(_ vision: CGRect, into size: CGSize) -> CGRect {
        let w = vision.width  * size.width
        let h = vision.height * size.height
        let x = vision.minX   * size.width
        let y = (1 - vision.maxY) * size.height   // flip Y: Vision origin is bottom-left
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func fitImageSize(in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let ratio = min(container.width  / imageSize.width,
                        container.height / imageSize.height)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }

    // MARK: – Vocabulary lookup

    private func lookupStatus(_ word: String) -> LearningStatus? {
        let key = word
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
        return savedItems.first {
            $0.text
                .lowercased()
                .trimmingCharacters(in: .punctuationCharacters) == key
        }?.status
    }

    private func strokeColor(for status: LearningStatus?) -> Color {
        switch status {
        case .none:     return .red     // unknown — not in dictionary at all
        case .new:      return .red     // in dictionary but never studied
        case .learning: return .yellow  // active SRS card
        case .mastered: return .clear   // fully known — hide the box
        }
    }
}

