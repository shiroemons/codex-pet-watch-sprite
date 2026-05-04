import CodexPetWatchSprite
import SwiftUI
import WidgetKit

struct CodexPetWidgetEntry: TimelineEntry {
    let date: Date
    let animation: CodexPetSpriteView.Animation
}

struct CodexPetWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CodexPetWidgetEntry {
        CodexPetWidgetEntry(date: Date(), animation: .idle)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (CodexPetWidgetEntry) -> Void
    ) {
        completion(CodexPetWidgetEntry(date: Date(), animation: .idle))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<CodexPetWidgetEntry>) -> Void
    ) {
        let entry = CodexPetWidgetEntry(date: Date(), animation: .idle)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30))))
    }
}

struct CodexPetWatchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CodexPetWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                pet(scale: 0.24)
            }
            .widgetURL(URL(string: "codexpet://open"))

        case .accessoryRectangular:
            HStack(spacing: 4) {
                pet(scale: 0.18)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Codex Pet")
                        .font(.caption2.weight(.semibold))
                    Text("Idle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
            .unredacted()
            .containerShape(RoundedRectangle(cornerRadius: 6))
            .widgetURL(URL(string: "codexpet://open"))

        case .accessoryInline:
            Label("Codex Pet", systemImage: "pawprint.fill")
                .unredacted()
                .widgetURL(URL(string: "codexpet://open"))

        case .accessoryCorner:
            Image(systemName: "pawprint.fill")
                .unredacted()
                .widgetURL(URL(string: "codexpet://open"))

        default:
            pet(scale: 0.22)
                .widgetURL(URL(string: "codexpet://open"))
        }
    }

    private func pet(scale: CGFloat) -> some View {
        CodexPetSpriteFrameView(
            animation: entry.animation,
            frameIndex: 0,
            scale: scale
        )
        .frame(
            width: CodexPetSpriteView.cellSize.width * scale,
            height: CodexPetSpriteView.cellSize.height * scale
        )
        .unredacted()
    }
}

struct CodexPetWatchWidget: Widget {
    let kind = "CodexPetWatchWidgetV2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexPetWidgetProvider()) { entry in
            CodexPetWatchWidgetEntryView(entry: entry)
                .widgetContainerBackground()
        }
        .configurationDisplayName("Codex Pet")
        .description("Show Codex Pet on the watch face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

@main
struct CodexPetWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexPetWatchWidget()
    }
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(watchOS 10.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self
        }
    }
}
