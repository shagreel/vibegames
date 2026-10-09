import SwiftUI

/// One card on the table.
///
/// The whole face is a single image: the artwork is drawn per combination, so
/// there is no symbol layout here any more. The selection ring and the rejection
/// flash are drawn on top, positioned to follow the card's painted edge inside
/// the image rather than the image's own bounds.
struct TrioCardView: View {
    let card: TrioCard
    let isSelected: Bool
    /// Set briefly when a selection turned out not to be a trio.
    let isRejected: Bool

    /// Width over height of the card artwork, including the transparent margin
    /// it carries for its own drop shadow. The cards were trimmed from 900x1260
    /// to this, taking out the empty cream above and below the platter, which is
    /// what lets three across and four down fit without scrolling.
    static let aspectRatio: CGFloat = 900.0 / 1153.0

    /// Where the painted card sits inside that artwork, measured off the alpha
    /// channel: 844 x 1095 px inset 28 from the left and 20 from the top.
    private enum Edge {
        static let width = 844.0 / 900.0
        static let height = 1095.0 / 1153.0
        static let offsetY = -0.00824
        static let cornerRadius = 62.0 / 844.0
    }

    private var ringColor: Color? {
        if isRejected { return VibeTheme.danger }
        if isSelected { return VibeTheme.vibeTrioBorder }
        return nil
    }

    /// The card faces ship as files in a folder reference, and SwiftUI's own
    /// `Image(_:)` searches the asset catalog only — it draws an empty view for a
    /// bundle file, and says so only in the console. So the image is loaded
    /// explicitly and handed over, and a card whose artwork is missing draws a
    /// visible placeholder rather than a hole in the board.
    private var face: Image? {
        UIImage(named: card.artworkName).map(Image.init(uiImage:))
    }

    var body: some View {
        Group {
            if let face {
                face.resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VibeTheme.danger.opacity(0.25))
                    .aspectRatio(Self.aspectRatio, contentMode: .fit)
                    .overlay {
                        Image(systemName: "questionmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(VibeTheme.danger)
                    }
            }
        }
            .overlay {
                if let ringColor {
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        RoundedRectangle(cornerRadius: w * Edge.width * Edge.cornerRadius,
                                         style: .continuous)
                            .strokeBorder(ringColor, lineWidth: max(2.5, w * 0.055))
                            .frame(width: w * Edge.width, height: h * Edge.height)
                            .position(x: w / 2, y: h / 2 + h * Edge.offsetY)
                    }
                }
            }
            .shadow(color: isSelected ? VibeTheme.vibeTrioBorder.opacity(0.45) : .black.opacity(0.16),
                    radius: isSelected ? 12 : 5, y: isSelected ? 0 : 2)
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isRejected)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.spokenDescription)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Cross-hatch for the back of a card.
private struct TrioBackLattice: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(9, rect.width * 0.24)
        let span = rect.height + rect.width
        var x = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + span, y: rect.maxY - span))
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + span, y: rect.minY + span))
            x += step
        }
        return path
    }
}

/// A face-down card.
///
/// Shown while a shared game waits for the host to start. Nobody gets to study
/// the table before everyone's clock does — the host included.
struct TrioCardBackView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shape = RoundedRectangle(cornerRadius: size.width * 0.10, style: .continuous)

            ZStack {
                shape.fill(VibeTheme.surfaceStrong)

                TrioBackLattice()
                    .stroke(VibeTheme.vibeTrioBorder.opacity(0.30), lineWidth: 1)
                    .clipShape(shape)

                shape.strokeBorder(VibeTheme.trioCardEdge, lineWidth: 1.5)
            }
        }
        .opacity(0.9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Face-down card")
    }
}
