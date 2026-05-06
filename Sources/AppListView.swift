import SwiftUI
import AppKit

struct AppListView: View {
    @ObservedObject var manager = FocusManager.shared
    @State private var searchText: String = ""
    @State private var hasAppeared: Bool = false

    var filteredApps: [AppInfo] {
        if searchText.isEmpty { return manager.installedApps }
        return manager.installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Block Apps")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Glass.textPrimary)
                Spacer()
                Text("\(manager.selectedAppBundleIDs.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Glass.textTertiary)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            // Search pill
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Glass.textTertiary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Glass.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 18)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredApps.enumerated()), id: \.element.id) { idx, app in
                        AppRow(
                            app: app,
                            selected: manager.selectedAppBundleIDs.contains(app.id),
                            onTap: { manager.toggleApp(app.id) }
                        )
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 8)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.85)
                                .delay(min(Double(idx) * 0.012, 0.25)),
                            value: hasAppeared
                        )

                        if idx < filteredApps.count - 1 {
                            Rectangle()
                                .fill(Glass.separator)
                                .frame(height: 0.5)
                                .padding(.leading, 50)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 6)
        }
        .disabled(manager.isSessionActive)
        .opacity(manager.isSessionActive ? 0.4 : 1.0)
        .blur(radius: manager.isSessionActive ? 1.0 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.isSessionActive)
        .onAppear {
            if !hasAppeared {
                DispatchQueue.main.async { hasAppeared = true }
            }
        }
    }
}

private struct AppRow: View {
    let app: AppInfo
    let selected: Bool
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Group {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 22, height: 22)
                    }
                }

                Text(app.name)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Glass.textPrimary)
                    .lineLimit(1)

                Spacer()

                ZStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Glass.accent)
                        .opacity(selected ? 1 : 0)
                        .scaleEffect(selected ? 1 : 0.6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
                }
                .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.06 : 0.0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
