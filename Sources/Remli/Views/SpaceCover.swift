import PhotosUI
import SwiftUI
import UIKit

/// The visual treatment every Space wears, over a photo or over nothing.
///
/// The point is that Spaces should look like a set. A screen of tiles where one is a bright
/// kitchen photo, one is a dark city at night and one is a flat orange rectangle reads as
/// three different apps. So the same four layers go over whatever is underneath — a colour
/// wash in the Space's own hue, a bloom, a darkening ramp, and a vignette — and the only
/// thing that varies between Spaces is the hue and how bright the source is.
///
/// It also solves the practical problem: a photo you chose has unknown brightness, and white
/// text has to stay readable on it. The ramp guarantees the bottom third is dark enough for
/// type no matter what you picked.
struct SpaceCover: View {

    let space: IdeaCategory
    /// Corner radius, so the same view serves a grid tile and a full-width header.
    var cornerRadius: CGFloat = Theme.Radius.lg

    private var accent: Color {
        Color(hex: space.colorHex) ?? Theme.Palette.ember
    }

    private var image: UIImage? {
        space.coverImageData.flatMap(UIImage.init(data:))
    }

    private var hasPreset: Bool {
        SpaceCoverPreset.preset(id: space.coverPresetID) != nil
    }

    private var washOpacity: Double {
        if image != nil { return 0.28 }
        return hasPreset ? 0.06 : 0.10
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // Slightly desaturated and darkened before anything else lands on it.
                    // Photographs arrive at every possible exposure; pulling them toward a
                    // common one is most of what makes the set feel deliberate.
                    .saturation(0.78)
                    .brightness(-0.06)
            } else if let preset = SpaceCoverPreset.preset(id: space.coverPresetID) {
                SpaceCoverPresetArt(preset: preset)
            } else {
                // Neither a photo nor a chosen cover: the Space's own colour. Two gradients
                // rather than one so it reads as a material with a light source rather than
                // a filled rectangle — a Space nobody has decorated must still look
                // finished.
                LinearGradient(
                    colors: [accent.opacity(0.62), accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // The wash. What makes a Space recognisably itself before you read the name —
            // heaviest over a photograph, which arrived with no allegiance to this Space,
            // and lightest over a designed cover, which was drawn for it.
            accent.opacity(washOpacity)
                .blendMode(.plusDarker)

            // A bloom in the top corner, so every tile is lit from the same direction.
            RadialGradient(
                colors: [.white.opacity(image == nil ? 0.14 : 0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 180
            )

            // The ramp that guarantees legible type over an unknown photo.
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )

            // A vignette to settle the edges.
            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: .center,
                startRadius: 60,
                endRadius: 260
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
    }
}

/// The button that opens the cover chooser.
struct SpaceCoverPicker: View {

    @Bindable var space: IdeaCategory
    @State private var isChoosing = false

    var body: some View {
        Button {
            isChoosing = true
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .padding(8)
                .background(Circle().fill(.black.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isChoosing) {
            SpaceCoverChooser(space: space)
        }
    }
}

/// Choosing what a Space looks like.
///
/// Your own photo first, because that is the one that will mean something to you, then
/// thirty built-in covers grouped by the kind of Space they suit. Grouping matters more
/// than it sounds: thirty ungrouped swatches is a wall to scroll past, whereas "Business"
/// with three under it is a decision you can make in a second.
struct SpaceCoverChooser: View {

    @Bindable var space: IdeaCategory

    @Environment(\.dismiss) private var dismiss

    @State private var selection: PhotosPickerItem?

    /// The long edge, in pixels. Comfortably past what a full-width header needs on the
    /// largest phone at 3× — beyond this is bytes nobody sees.
    private static let maxDimension: CGFloat = 900

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Space.xs),
        GridItem(.flexible(), spacing: Theme.Space.xs),
        GridItem(.flexible(), spacing: Theme.Space.xs),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {

                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                            Label(
                                space.coverImageData == nil ? "Choose your own photo" : "Replace photo",
                                systemImage: "photo"
                            )
                            .font(Theme.Typography.control)
                            .foregroundStyle(Theme.Palette.ember)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Space.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.Palette.surface)
                            )
                        }

                        if space.coverImageData != nil || space.coverPresetID != nil {
                            Button(role: .destructive) {
                                space.coverImageData = nil
                                space.coverPresetID = nil
                            } label: {
                                Text("Use the Space's colour instead")
                                    .font(Theme.Typography.meta)
                            }
                        }
                    }

                    ForEach(SpaceCoverPreset.grouped(), id: \.group) { entry in
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text(entry.group.rawValue.uppercased())
                                .font(Theme.Typography.sectionLabel)
                                .foregroundStyle(Theme.Palette.inkMuted)
                                .tracking(0.6)

                            LazyVGrid(columns: columns, spacing: Theme.Space.xs) {
                                ForEach(entry.presets) { preset in
                                    Button {
                                        // A chosen cover replaces a photo — two sources for
                                        // one slot would leave the person guessing which
                                        // one is actually showing.
                                        space.coverImageData = nil
                                        space.coverPresetID = preset.id
                                    } label: {
                                        PresetSwatch(
                                            preset: preset,
                                            isSelected: space.coverPresetID == preset.id
                                                && space.coverImageData == nil
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Space.md)
            }
            .background(Theme.Palette.canvas)
            .navigationTitle("Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: selection) { await load() }
    }

    private func load() async {
        guard let selection else { return }

        guard
            let data = try? await selection.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }

        space.coverImageData = Self.downscaled(image)
        space.coverPresetID = nil
        self.selection = nil
    }

    /// Resizes to `maxDimension` on the long edge and re-encodes as JPEG.
    ///
    /// A raw phone photo is around 4 MB. Every one of those would sync through the person's
    /// iCloud and be re-decoded on each scroll of the Spaces grid, to be drawn at 150 points.
    static func downscaled(_ image: UIImage) -> Data? {
        let longEdge = max(image.size.width, image.size.height)
        let scale = longEdge > maxDimension ? maxDimension / longEdge : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }

        // 0.8 is past the point where the difference is visible under a colour wash and a
        // darkening ramp, and roughly a fifth of the bytes of lossless.
        return rendered.jpegData(compressionQuality: 0.8)
    }
}

private struct PresetSwatch: View {
    let preset: SpaceCoverPreset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SpaceCoverPresetArt(preset: preset)
                .frame(height: 74)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.Palette.ember : .white.opacity(0.12),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                )

            Text(preset.name)
                .font(Theme.Typography.meta)
                .foregroundStyle(isSelected ? Theme.Palette.ember : Theme.Palette.inkMuted)
                .lineLimit(1)
        }
    }
}
