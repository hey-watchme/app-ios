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
    @State private var selectedLocalDate: String = ""
    @State private var showLogoutConfirmation = false
    @Binding var showRecordingSheet: Bool
    @State private var showQRScanner = false
    @State private var showDeviceRegistrationConfirm = false
    @State private var showSignUpPrompt = false  // ゲストモード時の会員登録促進シート
    @State private var showMyPage = false  // マイページ表示制御

    // 録音機能は新しいRecordingStoreが内部で管理

    // 動的な日付範囲管理（無限スクロール対応）
    // 初期値として今日の日付を設定（TabViewが空にならないように）
    @State private var dateRange: [String] = []
    @State private var isLoadingMoreDates = false

    // 初期ロード日数（起動時のパフォーマンス最適化）
    private let initialDaysToLoad = 7
    // 追加ロード日数（スクロール時）
    private let additionalDaysToLoad = 7
    
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
            .overlay(alignment: .top) {
                HeaderView(
                    showLogoutConfirmation: $showLogoutConfirmation,
                    showRecordingSheet: $showRecordingSheet,
                    showMyPage: $showMyPage
                )
                .zIndex(10)
            }
            
            // デモモードバナー（device_type == "demo"のデバイス選択時に表示）
            if deviceManager.isDemoDeviceSelected || deviceManager.isSampleDeviceSelected {
                DemoModeBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: deviceManager.isDemoDeviceSelected)
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
        let timezone = deviceManager.selectedDeviceTimezone
        let today = LocalDate.today(timezone: timezone)
        let dates = LocalDate.trailingDays(endingAt: today, count: initialDaysToLoad, timezone: timezone)

        dateRange = dates.isEmpty ? [today] : dates
        selectedLocalDate = today

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
        }

        print("📅 日付範囲を再同期: \(lastDate) → \(today)")
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
