import SwiftUI

/// Settings.
///
/// Every toggle that needs a system permission asks for it at the moment it is switched
/// on, never at launch — a permission prompt arrives with obvious context, and a declined
/// one leaves the rest of the app working.
struct SettingsView: View {

    @Bindable var store: ResurfacingSettingsStore
    let coordinator: ResurfacingCoordinator

    @Environment(\.dismiss) private var dismiss

    @State private var notificationsAuthorized = false
    @State private var isAddingTime = false
    @State private var newTime = Date()
    @State private var claudeSettings = ClaudeSettingsStore.shared
    @State private var isShowingClaudeConsent = false

    var body: some View {
        NavigationStack {
            Form {
                if !notificationsAuthorized {
                    Section {
                        Button("Allow notifications") {
                            Task {
                                notificationsAuthorized = await coordinator.enableNotifications()
                                await coordinator.refresh()
                            }
                        }
                    } footer: {
                        Text("Remli brings ideas back through notifications. Without them, everything below is switched off.")
                    }
                }

                dailySection
                weeklySection
                freeTimeSection
                quietHoursSection
                engineSection
                claudeSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                notificationsAuthorized = await coordinator.authorizationIsGranted
            }
            .onDisappear {
                Task { await coordinator.refresh() }
            }
        }
    }

    // MARK: - Sections

    private var dailySection: some View {
        Section {
            Toggle("Daily nudges", isOn: $store.settings.dailyNudgesEnabled)

            if store.settings.dailyNudgesEnabled {
                ForEach(store.settings.dailyTimes) { time in
                    HStack {
                        Text(time.displayString)
                        Spacer()
                        Button {
                            store.removeDailyTime(time)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        // With none left the feature is silently dead, which is more
                        // confusing than simply not letting the last one go.
                        .disabled(store.settings.dailyTimes.count <= 1)
                    }
                }

                Button("Add a time") { isAddingTime = true }
            }
        } header: {
            Text("Every day")
        } footer: {
            Text("Remli picks an idea you haven't looked at in a while. Add as many times as you want — nothing is ever sent twice about the same idea in one day.")
        }
        .sheet(isPresented: $isAddingTime) {
            TimePickerSheet(date: $newTime) {
                let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                store.addDailyTime(DayTime(hour: components.hour ?? 9, minute: components.minute ?? 0))
            }
        }
    }

    private var weeklySection: some View {
        Section {
            Toggle("Weekly review", isOn: $store.settings.weeklyReviewEnabled)

            if store.settings.weeklyReviewEnabled {
                Picker("Day", selection: $store.settings.weeklyReviewWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                Picker("Time", selection: $store.settings.weeklyReviewHour) {
                    ForEach(6...22, id: \.self) { hour in
                        Text(Self.hourLabel(hour)).tag(hour)
                    }
                }
            }
        } footer: {
            Text("A summary of what you captured and what's worth picking up.")
        }
    }

    private var freeTimeSection: some View {
        Section {
            Toggle("Suggest ideas when I'm free", isOn: Binding(
                get: { store.settings.freeTimeEnabled },
                set: { isOn in
                    guard isOn else {
                        store.settings.freeTimeEnabled = false
                        return
                    }
                    Task {
                        // Only ever asked for here, so the prompt makes sense.
                        // Written out rather than using `||` — its right-hand side is an
                        // autoclosure, which cannot contain an await.
                        var granted = coordinator.isCalendarAuthorized
                        if !granted {
                            granted = await coordinator.enableCalendarAccess()
                        }
                        store.settings.freeTimeEnabled = granted
                    }
                }
            ))

            if store.settings.freeTimeEnabled {
                Stepper(
                    "At least \(store.settings.freeTimeMinimumMinutes) minutes",
                    value: $store.settings.freeTimeMinimumMinutes,
                    in: 15...180,
                    step: 15
                )
            }
        } header: {
            Text("Free time")
        } footer: {
            Text("Remli reads when you're busy — never what your events are — and suggests something that fits the gap.")
        }
    }

    private var quietHoursSection: some View {
        Section {
            Picker("Not before", selection: $store.settings.dayStartHour) {
                ForEach(4...12, id: \.self) { Text(Self.hourLabel($0)).tag($0) }
            }
            Picker("Not after", selection: $store.settings.dayEndHour) {
                ForEach(15...23, id: \.self) { Text(Self.hourLabel($0)).tag($0) }
            }
        } header: {
            Text("Quiet hours")
        } footer: {
            Text("Nothing is ever scheduled outside these hours.")
        }
    }

    private var engineSection: some View {
        Section {
            LabeledContent("Filing ideas", value: coordinator.engineDescription)

            if let reason = FoundationModelsIntelligence.unavailabilityReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Intelligence")
        } footer: {
            Text("Everything runs on this iPhone. Your ideas are never sent anywhere.")
        }
    }

    /// The one place an idea can leave the device. Presented as an upgrade the user opts
    /// into, never as something already running.
    private var claudeSection: some View {
        Section {
            if claudeSettings.isActive {
                Picker("Model", selection: $claudeSettings.model) {
                    ForEach(ClaudeModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Button("Stop using Claude", role: .destructive) {
                    claudeSettings.disableAndForgetKey()
                }
            } else {
                Button("Use Claude instead…") {
                    isShowingClaudeConsent = true
                }
            }
        } header: {
            Text("Optional: Claude")
        } footer: {
            Text(claudeSettings.isActive
                 ? "Ideas are sent to Anthropic when Remli files them. Turning this off deletes your key and stops all outbound requests."
                 : "Sharper categories and better connections, using your own Anthropic API key. Off by default — your ideas stay on this iPhone until you turn it on.")
        }
        .sheet(isPresented: $isShowingClaudeConsent) {
            ClaudeConsentView(settings: claudeSettings)
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(.dateTime.hour())
    }
}

private struct TimePickerSheet: View {
    @Binding var date: Date
    var onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .navigationTitle("Add a time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            onAdd()
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.height(320)])
    }
}
