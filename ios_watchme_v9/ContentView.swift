//
//  ContentView.swift
//  ios_watchme_v9
//
//  シンプルな実装 - 日付変更バグ修正版
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var toastManager: ToastManager

    // シンプルな状態管理
    @State private var selectedDate: Date = Date()  // 初期値は現在時刻（後でonAppearで調整）
    @State private var showLogoutConfirmation = false
    @State private var showRecordingSheet = false
    @State private var showQRScanner = false
    @State private var showDeviceRegistrationConfirm = false
    @State private var showSignUpPrompt = false  // ゲストモード時の会員登録促進シート
    @State private var showMyPage = false  // マイページ表示制御

    // 録音機能は新しいRecordingStoreが内部で管理

    // 動的な日付範囲管理（無限スクロール対応）
    // 初期値として今日の日付を設定（TabViewが空にならないように）
    @State private var dateRange: [Date] = [Date()]
    @State private var isLoadingMoreDates = false

    // 初期ロード日数（起動時のパフォーマンス最適化）
    private let initialDaysToLoad = 7
    // 追加ロード日数（スクロール時）
    private let additionalDaysToLoad = 7
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ヘッダー（既存のHeaderViewを使用）
                HeaderView(
                    showLogoutConfirmation: $showLogoutConfirmation,
                    showRecordingSheet: $showRecordingSheet,
                    showMyPage: $showMyPage
                )
                
                // ✅ 権限ベース設計: 状態チェックロジック更新
                switch deviceManager.state {
                case .idle, .loading:
                    // ロード中または初期状態はスピナーを表示
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        Text("デバイス情報を取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                case .available:
                    // 常にダッシュボードを表示
                    ZStack(alignment: .top) {
                        TabView(selection: $selectedDate) {
                            ForEach(dateRange, id: \.self) { date in
                                SimpleDashboardView(
                                    date: date,
                                    selectedDate: $selectedDate
                                )
                                .tag(date)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .onChange(of: selectedDate) { oldValue, newValue in
                            // 端に到達したら追加データをロード
                            checkAndLoadMoreDates(currentDate: newValue)
                        }

                        // ローディングインジケーター（左端で過去データ読み込み中）
                        if isLoadingMoreDates, let firstDate = dateRange.first, selectedDate == firstDate {
                            VStack {
                                Spacer()
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("過去のデータを読み込み中...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                                Spacer()
                                    .frame(height: 100)
                            }
                        }

                        // 実デバイス未連携時のガイドオーバーレイ
                        // 条件: サンプルデバイスを除いた実デバイスが0件の場合に表示
                        if !deviceManager.hasRealDevices {
                            DeviceSetupGuideOverlay(
                                onSelectThisDevice: {
                                    print("🔘 DeviceSetupGuideOverlay: このデバイスで測定するボタン押下")
                                    print("✅ 録音シート表示（権限チェックは録音開始時に実行）")
                                    showRecordingSheet = true
                                },
                                onViewSample: {
                                    // DB連携済みサンプルデバイスを選択（ローカル疑似注入なし）
                                    let selected = deviceManager.selectSampleDevice()
                                    if !selected {
                                        toastManager.showInfo(
                                            title: "サンプルデバイスが未連携です",
                                            subtitle: "このデバイスを連携するか、QRコードで追加してください"
                                        )
                                    }
                                },
                                onScanQR: {
                                    // 権限チェック
                                    if userAccountManager.requireWritePermission() {
                                        showSignUpPrompt = true
                                        return
                                    }
                                    showQRScanner = true
                                }
                            )
                            .transition(.opacity)
                            .zIndex(1)
                        }
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
                            .foregroundColor(.orange)
                        Text("エラーが発生しました")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button(action: {
                            // 再度初期化処理を呼び出す
                            Task {
                                // ✅ CLAUDE.md: public.usersのuser_idを使用
                                if let userId = userAccountManager.effectiveUserId {
                                    await deviceManager.loadDevices(for: userId)
                                }
                            }
                        }) {
                            Text("リトライ")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.safeColor("AppAccentColor"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                }
            }
            
            // Floating Action Buttons (FAB)
            // deviceManagerのshouldShowFABプロパティで表示制御
            if deviceManager.shouldShowFAB {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        // FAB: Recording only (mic icon)
                        FloatingActionButton(icon: "mic.fill", action: {
                            print("🔘 FAB: 録音ボタン押下")
                            print("✅ 録音シート表示（権限チェックは録音開始時に実行）")
                            showRecordingSheet = true
                        })
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }

            // デモモードバナー（device_type == "demo"のデバイス選択時に表示）
            if deviceManager.isDemoDeviceSelected || deviceManager.isSampleDeviceSelected {
                DemoModeBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: deviceManager.isDemoDeviceSelected)
            }
        }
        .sheet(isPresented: $showRecordingSheet) {
            ZStack {
                FullScreenRecordingView()
                    .environmentObject(deviceManager)
                    .environmentObject(userAccountManager)
                    .environmentObject(recordingStore)

                // モーダル内でもトーストを表示
                VStack {
                    ToastOverlay(toastManager: ToastManager.shared)
                    Spacer()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        .sheet(isPresented: $showSignUpPrompt) {
            SignUpView()
                .environmentObject(userAccountManager)
        }
        .sheet(isPresented: $showMyPage) {
            UserInfoView(userAccountManager: userAccountManager)
                .environmentObject(deviceManager)
                .environmentObject(dataManager)
        }
        .onAppear {
            // デバイス初期化処理はMainAppViewの認証成功時に実行済み
            // 日付範囲の初期化
            initializeDateRange()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            syncDateRangeWithToday()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            syncDateRangeWithToday()
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
        let calendar = deviceManager.deviceCalendar
        let today = calendar.startOfDay(for: Date())

        // 初期ロード日数分の日付を生成
        guard let startDate = calendar.date(byAdding: .day, value: -(initialDaysToLoad - 1), to: today) else {
            dateRange = [today]
            selectedDate = today
            return
        }

        var dates: [Date] = []
        var currentDate = startDate

        while currentDate <= today {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        dateRange = dates
        selectedDate = today

        print("📅 日付範囲初期化: \(dates.count)日分（\(formatDate(dates.first!)) 〜 \(formatDate(today))）")
    }

    /// フォアグラウンド復帰や日付変更時に、現在日の範囲を再同期する
    private func syncDateRangeWithToday() {
        let calendar = deviceManager.deviceCalendar
        let today = calendar.startOfDay(for: Date())

        guard let lastDate = dateRange.last else {
            initializeDateRange()
            return
        }

        if selectedDate > today {
            selectedDate = today
        }

        guard lastDate < today else { return }

        let wasViewingLatestDate = calendar.isDate(selectedDate, inSameDayAs: lastDate)
        var newDates: [Date] = []
        var currentDate = calendar.date(byAdding: .day, value: 1, to: lastDate)

        while let nextDate = currentDate, nextDate <= today {
            newDates.append(nextDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: nextDate)
        }

        guard !newDates.isEmpty else { return }

        dateRange.append(contentsOf: newDates)

        if wasViewingLatestDate {
            selectedDate = today
        }

        print("📅 日付範囲を再同期: \(formatDate(lastDate)) → \(formatDate(today))")
    }

    /// 端に到達したら追加データを読み込む
    private func checkAndLoadMoreDates(currentDate: Date) {
        guard !isLoadingMoreDates else {
            print("⏳ 既に読み込み中です")
            return
        }

        guard let firstDate = dateRange.first else {
            print("⚠️ dateRangeが空です")
            return
        }

        let calendar = deviceManager.deviceCalendar

        // 左端（過去方向）に到達したかチェック
        if calendar.isDate(currentDate, inSameDayAs: firstDate) {
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

            let calendar = deviceManager.deviceCalendar

            // 追加日数分の日付を生成
            var newDates: [Date] = []
            for i in 1...additionalDaysToLoad {
                if let pastDate = calendar.date(byAdding: .day, value: -i, to: currentFirstDate) {
                    newDates.insert(pastDate, at: 0)
                }
            }

            if !newDates.isEmpty {
                // 新しい日付を先頭に追加
                dateRange.insert(contentsOf: newDates, at: 0)
                print("✅ \(newDates.count)日分追加: \(formatDate(newDates.first!)) 〜 \(formatDate(newDates.last!))")
                print("📊 現在の範囲: \(dateRange.count)日分")
            }

            isLoadingMoreDates = false
        }
    }

    /// 日付をフォーマット（デバッグ用）
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter.string(from: date)
    }
}
