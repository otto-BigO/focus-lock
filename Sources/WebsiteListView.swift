import SwiftUI

struct WebsiteListView: View {
    @ObservedObject var blocker = WebsiteBlocker.shared
    @ObservedObject var manager = FocusManager.shared
    @State private var customDomain: String = ""
    @State private var hasAppeared: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Block Websites")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Glass.textPrimary)
                Spacer()
                Text("\(blocker.selectedCount) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Glass.textTertiary)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            // Custom domain input (glass pill)
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Glass.textTertiary)
                TextField("Add custom domain (e.g. news.com)", text: $customDomain)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Glass.textPrimary)
                    .onSubmit { commitCustomDomain() }
                if !customDomain.isEmpty {
                    Button(action: commitCustomDomain) {
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Glass.accent)
                    }
                    .buttonStyle(.plain)
                }
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
                    ForEach(Array(blocker.blockedWebsites.enumerated()), id: \.element.id) { idx, site in
                        WebsiteRow(
                            entry: site,
                            onTap: { blocker.toggleSite(site.id) },
                            onRemove: site.isCustom ? { blocker.removeWebsite(site.id) } : nil
                        )
                        .equatable()
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 8)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.85)
                                .delay(min(Double(idx) * 0.02, 0.25)),
                            value: hasAppeared
                        )

                        if idx < blocker.blockedWebsites.count - 1 {
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

    private func commitCustomDomain() {
        let trimmed = customDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        blocker.addCustomDomain(trimmed)
        customDomain = ""
    }
}

private struct WebsiteRow: View, Equatable {
    let entry: WebsiteEntry
    let onTap: () -> Void
    let onRemove: (() -> Void)?

    static func == (lhs: WebsiteRow, rhs: WebsiteRow) -> Bool {
        lhs.entry == rhs.entry
    }

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 22)
                    Image(systemName: "globe")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Glass.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Glass.textPrimary)
                        .lineLimit(1)
                    Text(entry.domains.first ?? "")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Glass.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.red.opacity(0.7))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Glass.accent)
                    .opacity(entry.isSelected ? 1 : 0)
                    .scaleEffect(entry.isSelected ? 1 : 0.6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: entry.isSelected)
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
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
