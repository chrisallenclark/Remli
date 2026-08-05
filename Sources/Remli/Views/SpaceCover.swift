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
            } else {
                // No photo: the generated fallback. Two gradients rather than one so it
                // reads as a material with a light source, not a filled rectangle.
                LinearGradient(
                    colors: [accent.opacity(0.62), accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // The wash. What makes a Space recognisably itself before you read the name.
            accent.opacity(image == nil ? 0.10 : 0.28)
                .blendMode(.plusDarker)

            // A bloom in the top corner, so every tile is lit from the same direction.
            RadialGradient(
                colors: [.white.opacity(image == nil ? 0.18 : 0.12), .clear],
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

/// Picks and stores a Space's picture.
///
/// Downscaling happens here rather than at render: a phone photo is around 4 MB, and every
/// one of those would sync through the person's iCloud and be re-decoded on each scroll of
/// the Spaces grid, to be drawn at 150 points.
struct SpaceCoverPicker: View {

    @Bindable var space: IdeaCategory

    @State private var selection: PhotosPickerItem?

    /// The long edge, in pixels. Comfortably past what a full-width header needs on the
    /// largest phone at 3× — beyond this is bytes nobody sees.
    private static let maxDimension: CGFloat = 900

    var body: some View {
        Menu {
            // The picker has to be inside the menu rather than presented from it: a
            // PhotosPicker only presents from its own tap.
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Label(space.coverImageData == nil ? "Choose a picture" : "Change picture",
                      systemImage: "photo")
            }

            if space.coverImageData != nil {
                Button(role: .destructive) {
                    space.coverImageData = nil
                } label: {
                    Label("Remove picture", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .padding(8)
                .background(Circle().fill(.black.opacity(0.35)))
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
        self.selection = nil
    }

    /// Resizes to `maxDimension` on the long edge and re-encodes as JPEG.
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
