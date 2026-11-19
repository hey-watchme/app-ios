//
//  SavedRecordingsView.swift
//  ios_watchme_v9
//
//  The recordings the user saved (SavedRecordings), newest recording first, whatever the
//  report's period. Tapping one opens its SpotDetailView, where it can also be unsaved.
//

import SwiftUI
import Supabase

struct SavedRecordingsView: View {
    let deviceId: String

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var deviceManager: DeviceManager

    @State private var recordings: [DashboardTimeBlock] = []
    @State private var isLoading = true
    @State private var failed = false
    @State private var openSpot: DashboardTimeBlock?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .tint(.accentTeal)
                            .padding(.top, 60)
                    } else if failed {
                        message("読み込めませんでした。時間をおいて開き直してください")
                    } else if recordings.isEmpty {
                        message("保存した録音はまだありません。録音の詳細画面の左上の「保存」で、ここに残せます")
                    } else {
                        ForEach(recordings) { spot in
                            Button {
                                openSpot = spot
                            } label: {
                                row(spot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.darkBase.ignoresSafeArea())
            .navigationTitle("保存した録音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.darkBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationBackground(Color.darkBase)
        // Reload when a detail closes: it may have been unsaved there.
        .sheet(item: $openSpot, onDismiss: { Task { await load() } }) { spot in
            SpotDetailView(deviceId: deviceId, spotData: spot)
                .environmentObject(dataManager)
        }
        .task { await load() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(Color(white: 0.56))
            .multilineTextAlignment(.center)
            .padding(.top, 60)
            .padding(.horizontal, 12)
    }

    private func row(_ spot: DashboardTimeBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentTeal)
                    Text(dateText(spot.date))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(spot.displayTime)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                if let summary = spot.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.65))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            if let vibe = spot.vibeScore {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", vibe))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Color.vibeScoreColor(for: vibe))
                    Text("Vibe")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.45))
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.35))
                .padding(.top, 4)
        }
        .detailCard()
        .contentShape(Rectangle())
    }

    private func dateText(_ localDate: String?) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let localDate, let date = parser.date(from: localDate) else { return localDate ?? "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d (E)"
        return formatter.string(from: date)
    }

    // MARK: - Loading

    private struct DayRow: Decodable {
        let local_date: String?
        let recorded_at: String
    }

    /// The saved recordings, read through the day lists the rest of the app uses, so a
    /// saved recording opens with everything its detail page shows.
    private func load() async {
        failed = false
        do {
            let saved = try await SavedRecordings.recordedAts(deviceId: deviceId)
            guard !saved.isEmpty else {
                recordings = []
                isLoading = false
                return
            }
            let days: [DayRow] = try await SupabaseClientManager.shared.client
                .from("spot_results")
                .select("local_date, recorded_at")
                .eq("device_id", value: deviceId)
                .in("recorded_at", values: saved)
                .execute()
                .value
            let timezone = deviceManager.getTimezone(for: deviceId)
            var found: [DashboardTimeBlock] = []
            for date in Set(days.compactMap(\.local_date)).sorted() {
                let blocks = await dataManager.fetchDashboardTimeBlocks(deviceId: deviceId, localDate: date, timezone: timezone)
                found += blocks.filter { saved.contains($0.recordedAt ?? "") }
            }
            let order = Dictionary(uniqueKeysWithValues: saved.enumerated().map { ($1, $0) })
            recordings = found.sorted { (order[$0.recordedAt ?? ""] ?? .max) < (order[$1.recordedAt ?? ""] ?? .max) }
        } catch {
            print("❌ [SavedRecordings] Loading failed: \(error)")
            failed = true
        }
        isLoading = false
    }
}
