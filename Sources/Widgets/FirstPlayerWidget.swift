import AppIntents
import SwiftUI
import WidgetKit

/// The widget's identity in WidgetKit. The intent and the provider both need it,
/// and a typo in one is a button that redraws nothing.
private enum FirstPlayerWidgetKind {
    static let id = "FirstPlayerWidget"
}

struct FirstPlayerWidgetEntry: TimelineEntry {
    let date: Date
    let draw: FirstPlayer.Draw
}

struct FirstPlayerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FirstPlayerWidgetEntry {
        FirstPlayerWidgetEntry(
            date: .now,
            draw: FirstPlayer.Draw(question: "Who has the longest hair?", seat: .left)
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (FirstPlayerWidgetEntry) -> Void) {
        completion(FirstPlayerWidgetEntry(date: .now, draw: FirstPlayerWidgetStore.current()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<FirstPlayerWidgetEntry>) -> Void) {
        // Nothing changes with time. The only thing that moves this widget on is
        // the button, and that asks WidgetKit to read a new timeline.
        let entry = FirstPlayerWidgetEntry(date: .now, draw: FirstPlayerWidgetStore.current())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct FirstPlayerWidget: Widget {
    let kind = FirstPlayerWidgetKind.id

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FirstPlayerWidgetProvider()) { entry in
            FirstPlayerWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    FirstPlayerWidgetBackground()
                }
        }
        .configurationDisplayName("First Player")
        .description("One question, one answer — who goes first, without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct VibeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FirstPlayerWidget()
    }
}

/// The button on the card.
///
/// It only writes the next draw and asks WidgetKit to read it. The app does not
/// have to be running, and nothing in the app has to be open for this to work.
struct AnotherFirstPlayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Another first-player question"
    static var description = IntentDescription(
        "Draws another question and seat for who goes first."
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        _ = FirstPlayerWidgetStore.next()
        WidgetCenter.shared.reloadTimelines(ofKind: FirstPlayerWidgetKind.id)
        return .result()
    }
}

private struct FirstPlayerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: FirstPlayerWidgetEntry

    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 4 : 6) {
            HStack(spacing: 6) {
                Text("FIRST PLAYER")
                    .font(.system(size: isSmall ? 9 : 10, weight: .black, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer(minLength: 0)

                if !isSmall {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Text(entry.draw.question)
                .font(.system(size: isSmall ? 14 : (isLarge ? 22 : 17),
                              weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(isSmall ? 3 : (isLarge ? 4 : 2))
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(entry.draw.seat.instruction)
                .font(.system(size: isSmall ? 11 : 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Button(intent: AnotherFirstPlayerIntent()) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Another")
                }
                .font(.system(size: isSmall ? 10 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, isSmall ? 9 : 12)
                .frame(height: isSmall ? 26 : 28)
                .background { Capsule().fill(.white.opacity(0.16)) }
                .overlay { Capsule().stroke(.white.opacity(0.22), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Draw another question")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The tool's colours, from the utilities list, so the widget feels like the
/// screen it belongs to rather than a different app.
private struct FirstPlayerWidgetBackground: View {
    @Environment(\.colorScheme) private var colourScheme

    var body: some View {
        LinearGradient(
            colors: colourScheme == .dark
                ? [Color(red: 0.30, green: 0.34, blue: 0.42),
                   Color(red: 0.16, green: 0.19, blue: 0.26)]
                : [Color(red: 0.42, green: 0.47, blue: 0.56),
                   Color(red: 0.26, green: 0.31, blue: 0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
