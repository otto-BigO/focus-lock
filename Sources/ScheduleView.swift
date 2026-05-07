import SwiftUI

private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

struct ScheduleView: View {
    @ObservedObject var store = ScheduleStore.shared
    @State private var editing: ScheduledSession?
    @State private var showingAddSheet: Bool = false

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Scheduled Sessions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Glass.textPrimary)
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(Glass.accent.opacity(0.45))
                            )
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PressableScaleStyle())
                    .help("Add schedule")
                }
                .padding(.top, 24)
                .padding(.horizontal, 18)

                if store.schedules.isEmpty {
                    EmptyState()
                        .padding(.horizontal, 16)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(store.schedules) { s in
                                ScheduleRow(schedule: s) {
                                    editing = s
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddSheet) {
            ScheduleEditSheet(existing: nil) { newSchedule in
                store.add(newSchedule)
            }
        }
        .sheet(item: $editing) { s in
            ScheduleEditSheet(existing: s) { updated in
                store.update(updated)
            }
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(Color.white.opacity(0.30))
            Text("No schedules yet.\nTap + to add one.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Glass.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .glassPanel(cornerRadius: 14)
    }
}

private struct ScheduleRow: View {
    let schedule: ScheduledSession
    let onTap: () -> Void
    @ObservedObject var store = ScheduleStore.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(schedule.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Glass.textPrimary)
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(weekdayNames[day])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(schedule.weekdays.contains(day) ? .white : Glass.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(schedule.weekdays.contains(day) ? Glass.accent.opacity(0.35) : Color.white.opacity(0.04))
                            )
                    }
                }
                Text(String(format: "%02d:%02d — %d min", schedule.startHour, schedule.startMinute, schedule.durationMinutes))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Glass.textTertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in store.toggleEnabled(id: schedule.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Glass.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 12, strokeOpacity: 0.10, shadowRadius: 10, shadowY: 3, shadowOpacity: 0.10)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button(role: .destructive, action: { store.remove(id: schedule.id) }) {
                Label("Delete schedule", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add/Edit sheet

private struct ScheduleEditSheet: View {
    let existing: ScheduledSession?
    let onSave: (ScheduledSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager = FocusManager.shared
    @ObservedObject var blocker = WebsiteBlocker.shared

    @State private var name: String = "Focus Block"
    @State private var weekdays: Set<Int> = [1, 2, 3, 4, 5]
    @State private var hour: Int = 9
    @State private var minute: Int = 0
    @State private var duration: Int = 25

    private let durationPresets = [1, 15, 25, 45, 60, 90]

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(existing == nil ? "New Schedule" : "Edit Schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Glass.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Glass.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)
                .padding(.horizontal, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Name
                        Section(label: "Name") {
                            TextField("Schedule name", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(Glass.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        }

                        // Days
                        Section(label: "Days") {
                            HStack(spacing: 6) {
                                ForEach(0..<7, id: \.self) { day in
                                    Button(action: {
                                        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                                    }) {
                                        Text(weekdayNames[day])
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(weekdays.contains(day) ? .white : Glass.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 30)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(weekdays.contains(day) ? Glass.accent.opacity(0.40) : Color.white.opacity(0.06))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(weekdays.contains(day) ? 0.20 : 0.10), lineWidth: 0.5)
                                            )
                                    }
                                    .buttonStyle(PressableScaleStyle(pressedScale: 0.94))
                                }
                            }
                        }

                        // Time
                        Section(label: "Time") {
                            HStack(spacing: 8) {
                                Picker("", selection: $hour) {
                                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                Text(":")
                                    .foregroundColor(Glass.textSecondary)
                                Picker("", selection: $minute) {
                                    ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            }
                        }

                        // Duration
                        Section(label: "Duration") {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    ForEach(durationPresets, id: \.self) { mins in
                                        Button(action: { duration = mins }) {
                                            Text("\(mins)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(duration == mins ? .white : Glass.textPrimary)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                        .fill(duration == mins ? Glass.accent.opacity(0.40) : Color.white.opacity(0.06))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(duration == mins ? 0.22 : 0.10), lineWidth: 0.5)
                                                )
                                        }
                                        .buttonStyle(PressableScaleStyle(pressedScale: 0.94))
                                    }
                                }
                                DurationStepper(value: $duration, minValue: 1, maxValue: 180, step: 5)
                            }
                        }

                        // Blocked apps & websites - reuse current selection
                        Section(label: "Blocked Apps") {
                            HStack {
                                Image(systemName: "app.badge.checkmark")
                                    .foregroundColor(Glass.textSecondary)
                                    .font(.system(size: 12))
                                Text("Using current app selection (\(manager.selectedAppBundleIDs.count) app\(manager.selectedAppBundleIDs.count == 1 ? "" : "s"))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Glass.textSecondary)
                            }
                            Text("To change blocked apps, update your selection in the Focus tab")
                                .font(.system(size: 10))
                                .foregroundColor(Glass.textTertiary)
                                .padding(.top, 1)
                        }

                        Section(label: "Blocked Websites") {
                            let count = blocker.selectedCount
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(Glass.textSecondary)
                                    .font(.system(size: 12))
                                Text("Using current website selection (\(count) site\(count == 1 ? "" : "s"))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Glass.textSecondary)
                            }
                            Text("To change blocked websites, update your selection in the Focus tab")
                                .font(.system(size: 10))
                                .foregroundColor(Glass.textTertiary)
                                .padding(.top, 1)
                        }
                    }
                    .padding(.horizontal, 18)
                }

                HStack(spacing: 10) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Glass.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableScaleStyle())

                    Button(action: save) {
                        Text("Save")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(canSave
                                          ? Glass.accent.opacity(0.55)
                                          : Color.gray.opacity(0.30))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .opacity(canSave ? 1 : 0.6)
                    }
                    .buttonStyle(PressableScaleStyle())
                    .disabled(!canSave)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 460, height: 540)
        .preferredColorScheme(.dark)
        .onAppear {
            if let s = existing {
                name = s.label
                weekdays = s.weekdays
                hour = s.startHour
                minute = s.startMinute
                duration = s.durationMinutes
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !weekdays.isEmpty
    }

    private func save() {
        guard canSave else { return }
        let websiteIDs: Set<String> = Set(
            WebsiteBlocker.shared.blockedWebsites
                .filter { $0.isSelected }
                .map { $0.id.uuidString }
        )
        let id = existing?.id ?? UUID()
        let s = ScheduledSession(
            id: id,
            label: name.trimmingCharacters(in: .whitespaces),
            weekdays: weekdays,
            startHour: hour,
            startMinute: minute,
            durationMinutes: duration,
            blockedAppIDs: FocusManager.shared.selectedAppBundleIDs,
            blockedWebsiteIDs: websiteIDs,
            isEnabled: existing?.isEnabled ?? true
        )
        onSave(s)
        dismiss()
    }
}

private struct Section<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Glass.textTertiary)
                .textCase(.uppercase)
            content()
        }
    }
}
