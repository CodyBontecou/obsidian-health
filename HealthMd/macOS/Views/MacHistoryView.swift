#if os(macOS)
import SwiftUI

// MARK: - History View — Branded

struct MacHistoryView: View {
    @ObservedObject private var historyManager = ExportHistoryManager.shared
    @State private var selectedEntry: ExportHistoryEntry?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let rangeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        Group {
            if historyManager.history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.textMuted)
                    Text("No Export History")
                        .font(BrandTypography.subheading())
                        .foregroundStyle(Color.textPrimary)
                    Text("Export history will appear here after your first export.")
                        .font(BrandTypography.body())
                        .foregroundStyle(Color.textMuted)
                }
            } else {
                HSplitView {
                    historyList
                        .frame(minWidth: 350)

                    detailPanel
                        .frame(minWidth: 250, idealWidth: 300)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !historyManager.history.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear History", role: .destructive) {
                        selectedEntry = nil
                        historyManager.clearHistory()
                    }
                    .tint(Color.error)
                }
            }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List(historyManager.history, selection: $selectedEntry) { entry in
            HStack(spacing: 10) {
                statusIcon(for: entry)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.summaryDescription)
                        .font(BrandTypography.bodyMedium())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(Self.dateFormatter.string(from: entry.timestamp))
                            .font(BrandTypography.caption())
                            .foregroundStyle(Color.textMuted)

                        sourceBadge(for: entry)
                    }
                }

                Spacer()

                Text("\(entry.successCount)/\(entry.totalCount)")
                    .font(BrandTypography.value())
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.vertical, 2)
            .tag(entry)
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let entry = selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status header
                    HStack(spacing: 8) {
                        statusIcon(for: entry)
                        Text(entry.isFullSuccess ? "Success" : entry.success ? "Partial" : "Failed")
                            .font(BrandTypography.heading())
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandGlassCard()

                    // Details card
                    VStack(alignment: .leading, spacing: 12) {
                        BrandLabel("Details")

                        BrandDataRow(label: "Timestamp", value: Self.dateFormatter.string(from: entry.timestamp))
                        BrandDataRow(label: "Source", value: entry.source.rawValue)
                        BrandDataRow(label: "Date Range", value: dateRangeString(entry))
                        BrandDataRow(label: "Files Exported", value: "\(entry.successCount) of \(entry.totalCount)")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandGlassCard()

                    if let reason = entry.failureReason {
                        VStack(alignment: .leading, spacing: 8) {
                            BrandLabel("Failure Reason")
                            Text(reason.detailedDescription)
                                .font(BrandTypography.body())
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandGlassCard(tintOpacity: 0.02)
                    }

                    if !entry.failedDateDetails.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            BrandLabel("Failed Dates")
                            ForEach(entry.failedDateDetails, id: \.dateString) { detail in
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.error)
                                        .font(.caption)
                                    Text(detail.dateString)
                                        .font(BrandTypography.value())
                                        .foregroundStyle(Color.textPrimary)
                                    Text("— \(detail.reason.shortDescription)")
                                        .font(BrandTypography.caption())
                                        .foregroundStyle(Color.textMuted)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .brandGlassCard(tintOpacity: 0.02)
                    }

                    Spacer()
                }
                .padding(16)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.textMuted)
                Text("Select an export to see details")
                    .font(BrandTypography.body())
                    .foregroundStyle(Color.textMuted)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusIcon(for entry: ExportHistoryEntry) -> some View {
        Image(systemName: entry.isFullSuccess
              ? "checkmark.circle.fill"
              : entry.success ? "exclamationmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(entry.isFullSuccess ? Color.success : entry.success ? Color.warning : Color.error)
    }

    @ViewBuilder
    private func sourceBadge(for entry: ExportHistoryEntry) -> some View {
        Text(entry.source.rawValue)
            .font(BrandTypography.caption())
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .brandGlassPill()
    }

    private func dateRangeString(_ entry: ExportHistoryEntry) -> String {
        let start = Self.rangeDateFormatter.string(from: entry.dateRangeStart)
        let end = Self.rangeDateFormatter.string(from: entry.dateRangeEnd)
        return start == end ? start : "\(start) → \(end)"
    }
}

// Make ExportHistoryEntry selectable
extension ExportHistoryEntry: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ExportHistoryEntry, rhs: ExportHistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

#endif
