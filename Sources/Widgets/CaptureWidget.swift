import SwiftUI
import WidgetKit

/// The Lock Screen and Home Screen capture button.
///
/// This is the single highest-leverage surface in the app. An idea that has to survive
/// unlocking the phone, finding an icon and waiting for a launch is an idea that is
/// frequently gone by the time you get there. One tap from the Lock Screen, straight into
/// a live recording.
///
/// It deliberately holds no data, so it never shows something stale and needs no shared
/// container.
struct CaptureWidget: Widget {

    static let kind = "com.chrisallenclark.remli.capture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SingleEntryProvider()) { _ in
            CaptureWidgetView()
                .containerBackground(for: .widget) {
                    Color("Canvas", bundle: .main)
                }
        }
        .configurationDisplayName("Capture")
        .description("One tap to speak an idea.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall,
        ])
    }
}

/// Static content, so a single entry that never expires is the whole timeline.
private struct SingleEntryProvider: TimelineProvider {

    struct Entry: TimelineEntry {
        let date: Date
    }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct CaptureWidgetView: View {

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
            }
            .widgetURL(CaptureRoute.voiceURL)

        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                Text("Capture an idea")
                    .font(.system(size: 14, weight: .medium))
                Spacer(minLength: 0)
            }
            .widgetURL(CaptureRoute.voiceURL)

        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "lightbulb.max")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color("Ember", bundle: .main))

                Spacer(minLength: 0)

                Text("Capture")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color("Ink", bundle: .main))

                Text("Tap to speak")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("InkMuted", bundle: .main))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(CaptureRoute.voiceURL)
        }
    }
}
