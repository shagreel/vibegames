import SwiftUI
import UIKit

/// How to play, with real cards from the deck as the examples.
///
/// It is the one page whose instructions are diagrams rather than prose, so it
/// supplies its own sections — but the shell around them, including the back
/// button, comes from `GameInstructionsScaffold` like every other game's page.
struct TrioInstructionsView: View {
    /// The same platter and cheese, with the meat and the garnish all different
    /// — both halves of the rule in one picture. `TrioInstructionTests` checks
    /// the examples really are what the page says they are.
    static let trioExample: [TrioCard] = [
        TrioCard(base: .circle, cheese: .swiss, meat: .prosciutto, garnish: .grapes),
        TrioCard(base: .circle, cheese: .swiss, meat: .salami, garnish: .strawberry),
        TrioCard(base: .circle, cheese: .swiss, meat: .turkey, garnish: .pear),
    ]

    /// Two of the three meats agree and the third does not, so it fails on the
    /// meat alone — a clearer mistake to show than an arbitrary three cards.
    static let notATrioExample: [TrioCard] = [
        TrioCard(base: .circle, cheese: .swiss, meat: .prosciutto, garnish: .grapes),
        TrioCard(base: .circle, cheese: .swiss, meat: .prosciutto, garnish: .strawberry),
        TrioCard(base: .circle, cheese: .swiss, meat: .salami, garnish: .pear),
    ]

    private let features: [(name: String, options: String, symbol: String)] = [
        ("Platter", "round walnut · bamboo hexagon · slate rectangle", "circle.dashed"),
        ("Cheese", "swiss wedge · gouda cubes · brie round", "triangle"),
        ("Meat", "prosciutto ribbon · salami stack · turkey roll-up", "wind"),
        ("Garnish", "purple grapes · red strawberry · pear slices", "leaf"),
    ]

    var body: some View {
        // The same shell as every other game's page. Trio is the one whose
        // instructions are diagrams rather than prose, so it supplies its own
        // sections — but the header, the spacing and the framing are shared, and
        // that is what stops the five pages drifting apart.
        GameInstructionsScaffold(game: .trio,
                                 name: "Vibe Trio",
                                 identifier: "trio.instructions",
                                 intro: "Twelve charcuterie boards are dealt face up. "
                                      + "Your job is to find three of them that make a trio.") {
            whatsOnABoard
            theRule
            example(title: "This is a trio",
                    cards: Self.trioExample,
                    verdict: "Platter and cheese are the same on all three. Meat and garnish are different on all three.",
                    failing: nil,
                    tint: VibeTheme.tileCorrect)
            example(title: "This is not a trio",
                    cards: Self.notATrioExample,
                    verdict: "Two of them are prosciutto and the third is salami — two the same and one different. That breaks it.",
                    failing: "Meat",
                    tint: VibeTheme.danger)
            InstructionsBullets(title: "Playing", bullets: [
                GameInstructions.Bullet(
                    lead: "Solo",
                    text: "Clear the whole deck at your own pace. Stuck? **Hint** picks out one card of a trio — the other two are still yours to find."),
                GameInstructions.Bullet(
                    lead: "Race",
                    text: "Everyone gets the same boards on their own phone. First to six trios wins. No hints."),
                GameInstructions.Bullet(
                    lead: "Wrong three",
                    text: "They flash red and nothing moves. Look again — the cards stay put."),
            ])
        }
    }

    /// The cards are a folder reference in the bundle, which SwiftUI's own
    /// `Image(_:)` cannot see — it searches the asset catalog only, and draws an
    /// empty view for a bundle file without saying anything in the app.
    static func cardImage(_ name: String) -> Image? {
        UIImage(named: name).map(Image.init(uiImage:))
    }

    // MARK: - Sections

    private var whatsOnABoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("What's on a board")

            Text("Every board has four features, and each one comes three ways.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)

            TrioAnnotatedCard()

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    if index > 0 { Divider().overlay(VibeTheme.hairline) }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VibeTheme.vibeTrioBorder)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VibeTheme.primaryText)
                            Text(feature.options)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(VibeTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
            }
            .cardSurface()
        }
    }

    private var theRule: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("The rule")

            Text("Three cards make a trio when **every one of the four features is either the same on all three cards, or different on all three**.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(VibeTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Two matching and a third different is not a trio — on any feature.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VibeTheme.vibeTrioBorder.opacity(0.5), lineWidth: 1.5)
                }
        }
    }

    private func example(title: String,
                         cards: [TrioCard],
                         verdict: String,
                         failing: String?,
                         tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: failing == nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(VibeTheme.primaryText)
            }

            HStack(spacing: 8) {
                ForEach(cards) { card in
                    if let image = Self.cardImage(card.artworkName) {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            TrioFeatureBreakdown(cards: cards, failing: failing)

            Text(verdict)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VibeTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VibeTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VibeTheme.hairline, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(failing == nil ? "trio.example.trio" : "trio.example.notATrio")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .kerning(1.5)
            .foregroundStyle(VibeTheme.tertiaryText)
    }
}

// MARK: - Reusable pieces

/// One card with a label on each of its four zones, so the words in the list
/// below have somewhere to point.
private struct TrioAnnotatedCard: View {
    private let card = TrioInstructionsView.trioExample[0].artworkName

    /// Where each zone sits on a board, as fractions of the artwork.
    private let zones: [(label: String, x: CGFloat, y: CGFloat, edge: Edge.Set)] = [
        ("Platter", 0.50, 0.945, .bottom),
        ("Cheese", 0.55, 0.30, .top),
        ("Meat", 0.30, 0.70, .leading),
        ("Garnish", 0.70, 0.70, .trailing),
    ]

    var body: some View {
        Group {
            if let image = TrioInstructionsView.cardImage(card) {
                image.resizable().scaledToFit()
            } else {
                Color.clear.aspectRatio(900.0 / 1153.0, contentMode: .fit)
            }
        }
            .overlay {
                GeometryReader { proxy in
                    ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                        label(zone.label)
                            .position(x: proxy.size.width * zone.x,
                                      y: proxy.size.height * zone.y)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("A board labelled with its four features")
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .black, design: .rounded))
            .kerning(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background { Capsule().fill(Color.black.opacity(0.72)) }
    }
}

/// Reads three cards back and says, feature by feature, whether that feature is
/// the same on all three or different on all three.
private struct TrioFeatureBreakdown: View {
    let cards: [TrioCard]
    let failing: String?

    private static let order = ["Platter", "Cheese", "Meat", "Garnish"]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(Self.order, id: \.self) { feature in
                let values = cards.map { Self.value(of: feature, in: $0) }
                let same = Set(values).count == 1
                let isFailing = failing == feature
                HStack(spacing: 8) {
                    Image(systemName: isFailing ? "xmark" : (same ? "equal" : "not.equal"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isFailing ? VibeTheme.danger
                                         : (same ? VibeTheme.tileCorrect : VibeTheme.secondaryText))
                        .frame(width: 14)
                    Text(feature)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isFailing ? VibeTheme.danger : VibeTheme.primaryText)
                    Spacer(minLength: 0)
                    Text(same ? "all the same" : "all different")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VibeTheme.tertiaryText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.summary(cards: cards))
    }

    private static func value(of feature: String, in card: TrioCard) -> String {
        switch feature {
        case "Platter": return card.base.slug
        case "Cheese": return card.cheese.slug
        case "Meat": return card.meat.slug
        default: return card.garnish.slug
        }
    }

    private static func summary(cards: [TrioCard]) -> String {
        order.map { feature in
            let same = Set(cards.map { value(of: feature, in: $0) }).count == 1
            return "\(feature) \(same ? "all the same" : "all different")"
        }.joined(separator: ", ")
    }
}
