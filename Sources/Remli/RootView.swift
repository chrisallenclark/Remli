import SwiftUI

/// P0 placeholder.
///
/// The only job of this screen is to prove the pipeline: that CI can generate the
/// project, compile it, sign it, upload it to TestFlight, and that the result launches
/// on a real iPhone. It shows the build number so it is obvious at a glance whether the
/// build on the phone is the one that was just pushed.
///
/// P1 replaces this with the real design system and the ideas list.
struct RootView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        ZStack {
            Color("Canvas").ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lightbulb.max")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color("Ember"))

                Text("Remli")
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(Color("Ink"))

                Text("Capture the idea. Find the thread.")
                    .font(.callout)
                    .foregroundStyle(Color("InkMuted"))

                Text(version)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color("InkMuted"))
                    .padding(.top, 24)
            }
        }
    }
}

#Preview {
    RootView()
}
