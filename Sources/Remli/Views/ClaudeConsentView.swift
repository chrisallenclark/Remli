import SwiftUI

/// The consent screen for the optional Claude provider.
///
/// This is the only place in Remli where an idea leaves the device, so it gets an explicit
/// screen rather than a toggle with a footnote. It states plainly what is sent, to whom,
/// what is not sent, and how to undo it — before asking for the key.
///
/// App Review Guideline 5.1.2(i) requires disclosure and consent before sharing personal
/// data with a third-party AI service, but the screen is written for the person using the
/// app rather than for the reviewer.
struct ClaudeConsentView: View {

    @Bindable var settings: ClaudeSettingsStore

    @Environment(\.dismiss) private var dismiss

    @State private var key: String = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?

    private var canEnable: Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 && !isVerifying
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Label("What gets sent", systemImage: "arrow.up.forward.app")
                            .font(.headline)

                        Text("The text of an idea, and the titles of a few ideas it might relate to, are sent to Anthropic when Remli files it.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Space.xxs)

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Label("What doesn't", systemImage: "lock")
                            .font(.headline)

                        Text("No audio, ever. No account details. Nothing is sent for ideas captured while this is switched off.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Space.xxs)

                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Label("Turning it off", systemImage: "arrow.uturn.backward")
                            .font(.headline)

                        Text("Switching this off stops all outbound requests immediately and deletes your key from this iPhone. Ideas already filed stay exactly as they are.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Space.xxs)
                } header: {
                    Text("Before you turn this on")
                } footer: {
                    Text("Anthropic's handling of that text is covered by their privacy policy. Remli's own intelligence runs entirely on your iPhone and needs none of this — this only replaces it if you want sharper results.")
                }

                Section {
                    SecureField("sk-ant-…", text: $key)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("Model", selection: $settings.model) {
                        ForEach(ClaudeModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                } header: {
                    Text("Your API key")
                } footer: {
                    Text("Create one at console.anthropic.com. It's stored in this iPhone's Keychain, never synced to iCloud, and never sent anywhere except Anthropic. You pay Anthropic directly for usage.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await enable() }
                    } label: {
                        HStack {
                            if isVerifying {
                                ProgressView().controlSize(.small)
                            }
                            Text(isVerifying ? "Checking your key…" : "Turn on and send ideas to Claude")
                        }
                    }
                    .disabled(!canEnable)
                }
            }
            .navigationTitle("Use Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    /// Verifies the key with a real request before storing it.
    ///
    /// Accepting a key that turns out to be invalid would leave the user with a feature
    /// that looks enabled and silently falls back on every capture — the failure would be
    /// invisible. One round trip here makes it obvious immediately.
    private func enable() async {
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let probe = ClaudeIntelligence(model: settings.model, apiKey: trimmed)

        do {
            _ = try await probe.enrich(text: "A test idea, to check this key works.", existingCategories: [])
        } catch let error as ClaudeError {
            errorMessage = error.errorDescription
            return
        } catch {
            errorMessage = "Couldn't verify that key. Check your connection and try again."
            return
        }

        guard KeychainStore.save(trimmed) else {
            errorMessage = "Couldn't save the key to the Keychain."
            return
        }

        settings.isEnabled = true
        dismiss()
    }
}
