//
//  ContentView.swift
//  ios_watchme_v9
//
//  シンプルな実装 - 日付変更バグ修正版
//

import SwiftUI
import UIKit
import Supabase

struct ContentView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var toastManager: ToastManager
    @ObservedObject private var researchConsent = ResearchConsentStore.shared
    @ObservedObject private var audioKeep = AudioKeepStore.shared

    // シンプルな状態管理
    @State private var selectedLocalDate: String = ""
    @State private var showLogoutConfirmation = false
    @Binding var showRecordingSheet: Bool
    @State private var showQRScanner = false
    @State private var showDeviceRegistrationConfirm = false
    @State private var showMyPage = false  // マイページ表示制御

    // 録音機能は新しいRecordingStoreが内部で管理

    // 動的な日付範囲管理（無限スクロール対応）
    // Filled in init so the pager is laid out once, already on today (an empty
    // range filled in onAppear made the first frame jump).
    @State private var dateRange: [String]
    @State private var isLoadingMoreDates = false
    /// The day the home opened on by itself (the newest day with a recording). While the
    /// person stays on it, coming back to the app moves on to a newer one.
    @State private var autoSelectedDate: String?
    /// The day of a recording made in this session, which may not have reached the server yet.
    @State private var recordedHereDate: String?
    /// False until the day to open on is known; the pager waits rather than show today first.
    @State private var startDayKnown: Bool

    // 初期ロード日数（起動時のパフォーマンス最適化）
    private let initialDaysToLoad = 7
    // 追加ロード日数（スクロール時）
    private let additionalDaysToLoad = 7

    init(showRecordingSheet: Binding<Bool>) {
        _showRecordingSheet = showRecordingSheet
        let today = LocalDate.today(timezone: TimeZone.current)
        let deviceId = UserDefaults.standard.string(forKey: "watchme_selected_device_id")
        let start = deviceId.flatMap(Self.rememberedNewestDay).map { min($0, today) } ?? today
        var dates = LocalDate.trailingDays(endingAt: today, count: 7, timezone: TimeZone.current)
        // The pager must hold the day it opens on, even an older one
        while let first = dates.first, start < first,
              let before = LocalDate.addingDays(-1, to: first, timezone: TimeZone.current) {
            dates.insert(before, at: 0)
        }
        _dateRange = State(initialValue: dates.isEmpty ? [today] : dates)
        _selectedLocalDate = State(initialValue: start)
        _autoSelectedDate = State(initialValue: start)
        _startDayKnown = State(initialValue: deviceId.flatMap(Self.rememberedNewestDay) != nil)
    }

    // MARK: - The day the home opens on

    /// The newest day with a recording, as last read from the server, per device. The home
    /// opens straight on it, so it does not first draw today and then move.
    private static func rememberedNewestDay(deviceId: String) -> String? {
        UserDefaults.standard.string(forKey: "home_newest_recorded_day_\(deviceId)")
    }

    private static func rememberNewestDay(_ localDate: String, deviceId: String) {
        UserDefaults.standard.set(localDate, forKey: "home_newest_recorded_day_\(deviceId)")
    }
    
    var body: some View {
        ZStack {
            Color.darkBase.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ✅ 権限ベース設計: 状態チェックロジック更新
                switch deviceManager.state {
                case .idle, .loading:
                    // ロード中または初期状態はスピナーを表示
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("デバイス情報を取得中...")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.56))
                    }
                    Spacer()

                case .available where !startDayKnown:
                    // The first time on this device: wait for the newest day rather than show today first
                    ScrollView {
                        SkeletonView()
                            // Where the day starts under the date header (SimpleDashboardView)
                            .padding(.top, 145)
                    }
                    .scrollDisabled(true)

                case .available:
                    // 常にダッシュボードを表示
                    ZStack(alignment: .top) {
                        TabView(selection: $selectedLocalDate) {
                            ForEach(dateRange, id: \.self) { localDate in
                                SimpleDashboardView(
                                    localDate: localDate,
                                    selectedLocalDate: $selectedLocalDate
                                )
                                .tag(localDate)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .onChange(of: selectedLocalDate) { oldValue, newValue in
                            ensureDateRangeIncludes(newValue)
                            // 端に到達したら追加データをロード
                            checkAndLoadMoreDates(currentLocalDate: newValue)
                        }

                        // ローディングインジケーター（左端で過去データ読み込み中）
                        if isLoadingMoreDates, let firstDate = dateRange.first, selectedLocalDate == firstDate {
                            VStack {
                                Spacer()
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("過去のデータを読み込み中...")
                                        .font(.caption)
                                        .foregroundColor(Color(white: 0.56))
                                }
                                .padding()
                                .background(Color.darkSurface.opacity(0.95))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                                Spacer()
                                    .frame(height: 100)
                            }
                        }

                        // 実デバイス未連携時のガイドオーバーレイは廃止
                    }
                    .id(deviceManager.selectedDeviceID) // デバイスIDで再構築を制御
                    .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
                        if oldValue != newValue && newValue != nil {
                            // デバイスが変更されたら日付範囲をリセット
                            initializeDateRange()
                        }
                    }

                case .error(let errorMessage):
                    // エラーが発生した
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.accentTealMuted)
                        Text("エラーが発生しました")
                            .font(.title3)
                            .foregroundColor(.white)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.56))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: {
                            // 再度初期化処理を呼び出す
                            Task {
                                // ✅ CLAUDE.md: public.usersのuser_idを使用
                                if let userId = userAccountManager.effectiveUserId {
                                    await deviceManager.loadDevices(for: userId)
                                } else {
                                    await deviceManager.loadSampleForGuest()
                                }
                            }
                        }) {
                            Text("リトライ")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentTeal)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                }
            }
            // Fill the screen in every state: the header overlay takes this view's width,
            // and the narrow loading state squeezed it before the dashboard arrived.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                HeaderView(
                    showLogoutConfirmation: $showLogoutConfirmation,
                    showRecordingSheet: $showRecordingSheet,
                    showMyPage: $showMyPage
                )
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                Task {
                    await handleQRCodeScanned(scannedCode)
                }
            }
        }
        .alert("ログアウト確認", isPresented: $showLogoutConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                Task {
                    await userAccountManager.signOut()
                }
            }
        } message: {
            Text("本当にログアウトしますか？")
        }
        .alert("デバイスを連携", isPresented: $showDeviceRegistrationConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("連携", role: .none) {
                handleRegisterCurrentDevice()
            }
        } message: {
            Text("このデバイスのマイクを使って音声情報を分析します。")
        }
        .sheet(isPresented: $showMyPage) {
            UserInfoView(userAccountManager: userAccountManager)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
                .preferredColorScheme(.dark)
        }
        .task {
            // Research consent: apply the sign-up choice, or ask once (not for guests).
            guard userAccountManager.authState.isAuthenticated else { return }
            await researchConsent.syncAfterSignIn(
                email: userAccountManager.currentUser?.email,
                isAnonymous: userAccountManager.isAnonymousUser
            )
            await audioKeep.syncAfterSignIn(isAnonymous: userAccountManager.isAnonymousUser)
        }
        .sheet(isPresented: $researchConsent.showFirstLoginPrompt) {
            ResearchConsentPromptView(store: researchConsent)
        }
        // Keeping audio is asked after the research question, never on top of it
        .background(
            Color.clear.sheet(isPresented: Binding(
                get: { audioKeep.showPrompt && !researchConsent.showFirstLoginPrompt },
                set: { if !$0 { audioKeep.showPrompt = false } }
            )) {
                AudioKeepPromptView(store: audioKeep)
            }
        )
        .onAppear {
            // デバイス初期化処理はMainAppViewの認証成功時に実行済み
            // 日付範囲の初期化
            initializeDateRange()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            syncDateRangeWithToday()
            Task { await showNewestRecordedDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            syncDateRangeWithToday()
            Task { await showNewestRecordedDay() }
        }
        .onChange(of: recordingStore.state.isRecording) { wasRecording, isRecording in
            // A recording just stopped: show today, where its progress and result appear
            guard wasRecording, !isRecording else { return }
            syncDateRangeWithToday()
            let today = LocalDate.today(timezone: deviceManager.selectedDeviceTimezone)
            selectedLocalDate = today
            autoSelectedDate = today
            recordedHereDate = today
            if let deviceId = deviceManager.selectedDeviceID {
                Self.rememberNewestDay(today, deviceId: deviceId)
            }
        }
        .onChange(of: recordingStore.state.errorMessage) { oldValue, newValue in
            // 録音エラーをToastで表示（エラーメッセージ統一）
            if let error = newValue, !error.isEmpty, recordingStore.state.showError {
                toastManager.showError(title: "録音エラー", subtitle: error)
                print("🍞 [Toast] 録音エラー表示: \(error)")
            }
        }
    }

    // MARK: - このデバイスを登録する処理
    private func handleRegisterCurrentDevice() {
        guard let userId = userAccountManager.effectiveUserId else {
            print("❌ ユーザー情報の取得に失敗しました")
            toastManager.showError(title: "連携に失敗しました", subtitle: "ユーザー情報を取得できません")
            return
        }

        Task {
            do {
                // DeviceManagerのregisterDeviceメソッドを呼び出す（完了まで待機）
                let _ = try await deviceManager.registerDevice(userId: userId)

                // デバイスリストを再読み込み
                await deviceManager.loadDevices(for: userId)

                print("✅ デバイス登録成功")
            } catch {
                print("❌ デバイス登録エラー: \(error)")
                toastManager.showError(
                    title: "デバイス連携に失敗しました",
                    subtitle: error.localizedDescription
                )
            }
        }
    }


    // MARK: - QRコードスキャン処理
    private func handleQRCodeScanned(_ code: String) async {
        // 既に追加済みかチェック
        if deviceManager.devices.contains(where: { $0.device_id == code }) {
            print("⚠️ このデバイスは既に追加されています")
            return
        }

        // デバイスを追加
        do {
            // ✅ CLAUDE.md: public.usersのuser_idを使用
            if let userId = userAccountManager.effectiveUserId {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                print("✅ デバイスを追加しました: \(code)")
            } else {
                print("❌ ユーザー情報の取得に失敗しました")
            }
        } catch {
            print("❌ デバイスの追加に失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - 日付範囲管理（無限スクロール対応）

    /// 日付範囲の初期化（起動時・デバイス変更時）
    private func initializeDateRange() {
        let timezone = deviceManager.selectedDeviceTimezone
        let today = LocalDate.today(timezone: timezone)
        let dates = LocalDate.trailingDays(endingAt: today, count: initialDaysToLoad, timezone: timezone)

        dateRange = dates.isEmpty ? [today] : dates
        let remembered = deviceManager.selectedDeviceID.flatMap(Self.rememberedNewestDay).map { min($0, today) }
        startDayKnown = remembered != nil
        let start = remembered ?? today
        ensureDateRangeIncludes(start)
        selectedLocalDate = start
        autoSelectedDate = start
        Task { await showNewestRecordedDay() }

        print("📅 日付範囲初期化: \(dateRange.count)日分（\(dateRange.first ?? today) 〜 \(today)）")
    }

    /// フォアグラウンド復帰や日付変更時に、現在日の範囲を再同期する
    private func syncDateRangeWithToday() {
        let timezone = deviceManager.selectedDeviceTimezone
        let today = LocalDate.today(timezone: timezone)

        guard let lastDate = dateRange.last else {
            initializeDateRange()
            return
        }

        if selectedLocalDate > today {
            selectedLocalDate = today
        }

        guard lastDate < today else { return }

        let wasViewingLatestDate = selectedLocalDate == lastDate
        var newDates: [String] = []
        var currentDate = LocalDate.addingDays(1, to: lastDate, timezone: timezone)

        while let nextDate = currentDate, nextDate <= today {
            newDates.append(nextDate)
            currentDate = LocalDate.addingDays(1, to: nextDate, timezone: timezone)
        }

        guard !newDates.isEmpty else { return }

        dateRange.append(contentsOf: newDates)

        if wasViewingLatestDate {
            selectedLocalDate = today
            // Still the day picked by the app; showNewestRecordedDay may move it back
            if autoSelectedDate == lastDate { autoSelectedDate = today }
        }

        print("📅 日付範囲を再同期: \(lastDate) → \(today)")
    }

    /// The home opens on the newest day that has a recording, not on today: someone who
    /// records at dinner would otherwise see an empty today until the next dinner
    /// (platform docs/product/screens.md "ホーム"). Today when nothing was recorded yet.
    /// Only moves while the person is still on the day it picked last time.
    private func showNewestRecordedDay() async {
        guard let deviceId = deviceManager.selectedDeviceID else {
            startDayKnown = true
            return
        }
        struct Row: Decodable { let local_date: String? }
        let rows: [Row]
        do {
            rows = try await SupabaseClientManager.shared.client
                .from("spot_results")
                .select("local_date")
                .eq("device_id", value: deviceId)
                .not("local_date", operator: .is, value: "null")
                .order("local_date", ascending: false)
                .limit(1)
                .execute()
                .value
        } catch {
            // Keep the day it opened on; show the pager rather than wait
            print("❌ [Home] could not read the newest day: \(error)")
            await MainActor.run { startDayKnown = true }
            return
        }
        let today = LocalDate.today(timezone: deviceManager.selectedDeviceTimezone)
        let newest = min(max(rows.first?.local_date ?? today, recordedHereDate ?? ""), today)
        await MainActor.run {
            guard deviceManager.selectedDeviceID == deviceId else { return }
            Self.rememberNewestDay(newest, deviceId: deviceId)
            defer { startDayKnown = true }
            guard selectedLocalDate == autoSelectedDate || autoSelectedDate == nil,
                  newest != selectedLocalDate else { return }
            ensureDateRangeIncludes(newest)
            selectedLocalDate = newest
            autoSelectedDate = newest
        }
    }

    /// 端に到達したら追加データを読み込む
    private func checkAndLoadMoreDates(currentLocalDate: String) {
        guard !isLoadingMoreDates else {
            print("⏳ 既に読み込み中です")
            return
        }

        guard let firstDate = dateRange.first else {
            print("⚠️ dateRangeが空です")
            return
        }

        // 左端（過去方向）に到達したかチェック
        if currentLocalDate == firstDate {
            print("📍 左端に到達 - 過去のデータを読み込みます")
            loadMorePastDates()
        }

        // 注意: 右端（未来方向）は今日が最大なので拡張不要
    }

    /// 過去の日付を追加読み込み
    private func loadMorePastDates() {
        guard let currentFirstDate = dateRange.first else { return }

        isLoadingMoreDates = true
        print("🔄 過去\(additionalDaysToLoad)日分のデータを読み込み開始...")

        Task { @MainActor in
            // 非同期で少し待機（UIの反応性向上）
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒

            // 追加日数分の日付を生成
            let timezone = deviceManager.selectedDeviceTimezone
            var newDates: [String] = []
            for i in 1...additionalDaysToLoad {
                if let pastDate = LocalDate.addingDays(-i, to: currentFirstDate, timezone: timezone) {
                    newDates.insert(pastDate, at: 0)
                }
            }

            if !newDates.isEmpty {
                // 新しい日付を先頭に追加
                dateRange.insert(contentsOf: newDates, at: 0)
                print("✅ \(newDates.count)日分追加: \(newDates.first!) 〜 \(newDates.last!)")
                print("📊 現在の範囲: \(dateRange.count)日分")
            }

            isLoadingMoreDates = false
        }
    }

    private func ensureDateRangeIncludes(_ localDate: String) {
        guard !localDate.isEmpty else { return }

        if dateRange.isEmpty {
            dateRange = [localDate]
            return
        }

        let timezone = deviceManager.selectedDeviceTimezone

        if let firstDate = dateRange.first, localDate < firstDate {
            var datesToInsert: [String] = []
            var currentDate = localDate

            while currentDate < firstDate {
                datesToInsert.append(currentDate)
                guard let nextDate = LocalDate.addingDays(1, to: currentDate, timezone: timezone) else {
                    break
                }
                currentDate = nextDate
            }

            dateRange.insert(contentsOf: datesToInsert, at: 0)
            return
        }

        if let lastDate = dateRange.last, localDate > lastDate {
            var datesToAppend: [String] = []
            var currentDate = LocalDate.addingDays(1, to: lastDate, timezone: timezone)

            while let nextDate = currentDate, nextDate <= localDate {
                datesToAppend.append(nextDate)
                currentDate = LocalDate.addingDays(1, to: nextDate, timezone: timezone)
            }

            dateRange.append(contentsOf: datesToAppend)
        }
    }
}
