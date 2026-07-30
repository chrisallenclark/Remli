import SwiftData
import SwiftUI

/// The app shell.
///
/// Deliberately not a TabView yet. Empty tabs for features that do not exist are worse
/// than no tabs; Map and Review appear once they have something in them.
struct RootView: View {

    var storeIsEphemeral: Bool = false

    @State private var isCapturing = false

    var body: some View {
        NavigationStack {
            IdeasListView()
                .background(Theme.Palette.canvas)
                .navigationTitle("Ideas")
                .navigationBarTitleDisplayMode(.large)
                .safeAreaInset(edge: .bottom) {
                    CaptureButton { isCapturing = true }
                }
        }
        .sheet(isPresented: $isCapturing) {
            CaptureSheet()
        }
        .overlay(alignment: .top) {
            if storeIsEphemeral {
                EphemeralStoreBanner()
            }
        }
    }
}

/// The primary action, and the reason the app exists. Given prominence accordingly: a
/// wide target at the bottom of the screen, reachable one-handed.
private struct CaptureButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Capture")
                    .font(Theme.Typography.control)
            }
            .foregroundStyle(Theme.Palette.canvas)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(
                Capsule(style: .continuous).fill(Theme.Palette.ember)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Space.lg)
        .padding(.bottom, Theme.Space.xs)
        .background(.ultraThinMaterial)
    }
}

/// Shown when the persistent store could not be opened and the app is running against
/// memory only. Being loud about this is the honest choice — anything captured in this
/// state will not survive a relaunch.
private struct EphemeralStoreBanner: View {
    var body: some View {
        Text("Storage unavailable — ideas captured now won't be saved.")
            .font(Theme.Typography.meta)
            .foregroundStyle(Theme.Palette.canvas)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.xs)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.9))
    }
}

#Preview {
    RootView()
        .modelContainer(try! RemliSchema.makeContainer(inMemory: true))
}
