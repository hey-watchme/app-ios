//
//  ContentView.swift
//  ios_watchme_v9
//
//  シンプルな実装 - 日付変更バグ修正版
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userAccountManager: UserAccountManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    // シンプルな状態管理
    @State private var selectedDate: Date = Date()  // 初期値は現在時刻（後でonAppearで調整）
    @State private var showLogoutConfirmation = false
    @State private var showRecordingSheet = false
    @State private var showQRScanner = false
    @State private var showDeviceRegistrationConfirm = false
    @State private var showSignUpPrompt = false  // ゲストモード時の会員登録促進シート

    // NetworkManagerの初期化（録音機能のため必要）
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var networkManager: NetworkManager?

    // 動的な日付範囲管理（無限スクロール対応）
    @State private var dateRange: [Date] = []
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
                    showRecordingSheet: $showRecordingSheet
                )
                
                // シンプルな表示制御: selectedDeviceIDの有無のみで判断
                if deviceManager.state == .idle || deviceManager.state == .loading {
                    // ロード中はスピナーを表示
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
                } else if deviceManager.selectedDeviceID != nil {
                    // デバイスが選択されている → ダッシュボード表示
                    ZStack(alignment: .top) {
                        TabView(selection: $selectedDate) {
                            ForEach(dateRange, id: \.self) { date in
                                SimpleDashboardView(
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
                    }
                    .id(deviceManager.selectedDeviceID) // デバイスIDで再構築を制御
                    .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
                        if oldValue != newValue && newValue != nil {
                            // デバイスが変更されたら日付範囲をリセット
                            initializeDateRange()
                        }
                    }
                } else {
                    // デバイスが選択されていない → ガイド画面表示
                    noDevicesView
                }

                // エラー時の表示
                if case .error(let errorMessage) = deviceManager.state {
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
                                if let userId = userAccountManager.currentUser?.profile?.userId {
                                    await deviceManager.initializeDeviceState(for: userId)
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
            
            // Floating Action Button (FAB)
            // deviceManagerのshouldShowFABプロパティで表示制御
            if deviceManager.shouldShowFAB {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            print("🔘 FAB: 録音ボタン押下")
                            print("🔍 authState: \(userAccountManager.authState)")

                            // ゲストモードチェック
                            if userAccountManager.requireAuthentication() {
                                print("❗️ ゲストモード検出 - 会員登録シート表示")
                                showSignUpPrompt = true
                                return
                            }
                            print("✅ 認証済み - 録音シート表示")
                            showRecordingSheet = true
                        }) {
                            ZStack {
                                // 背景の円（影付き）
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.safeColor("RecordingActive"), Color.safeColor("RecordingActive").opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Color.safeColor("RecordingActive").opacity(0.4), radius: 8, x: 0, y: 4)
                                
                                // マイクアイコン
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showRecordingSheet) {
            if let networkManager = networkManager {
                RecordingView(audioRecorder: audioRecorder, networkManager: networkManager)
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
        .onAppear {
            initializeNetworkManager()

            // AudioRecorderの遅延初期化（パフォーマンス改善）
            audioRecorder.startLazyInitialization()

            // デバイス初期化処理はMainAppViewの認証成功時に実行済み

            // 日付範囲の初期化
            initializeDateRange()
        }
    }
    
    private func initializeNetworkManager() {
        audioRecorder.deviceManager = deviceManager
        networkManager = NetworkManager(userAccountManager: userAccountManager, deviceManager: deviceManager)

        if let authUser = userAccountManager.currentUser {
            networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
    }

    // MARK: - このデバイスを登録する処理
    private func handleRegisterCurrentDevice() {
        guard let userId = userAccountManager.currentUser?.profile?.userId else {
            print("❌ ユーザー情報の取得に失敗しました")
            return
        }

        Task {
            // DeviceManagerのregisterDeviceメソッドを呼び出す（完了まで待機）
            await deviceManager.registerDevice(userId: userId)

            await MainActor.run {
                // エラーチェック
                if let error = deviceManager.registrationError {
                    print("❌ デバイス登録エラー: \(error)")
                } else if !deviceManager.userDevices.isEmpty {
                    // 登録成功 - デバイスが追加されたのでUIが自動的に更新される
                    print("✅ デバイス登録成功")
                } else {
                    print("❌ デバイスの登録に失敗しました")
                }
            }
        }
    }

    // MARK: - デバイスなし画面
    private var noDevicesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // タイトル「ダッシュボード」
            Text("ダッシュボード")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 40)
                .padding(.horizontal, 40)

            // 説明文
            Text("あなたの声から、気分・行動・感情を分析します。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.horizontal, 40)

            // グラフアイコン（うっすらグレー、中央配置）
            Spacer()

            HStack {
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.gray.opacity(0.15))
                Spacer()
            }

            Spacer()

            // ボタンエリア
            VStack(spacing: 16) {
                // 1. このデバイスで測定するボタン
                Button(action: {
                    print("🔘 noDevicesView: このデバイスで測定するボタン押下")
                    print("🔍 authState: \(userAccountManager.authState)")

                    // ゲストモードチェック
                    if userAccountManager.requireAuthentication() {
                        print("❗️ ゲストモード検出 - 会員登録シート表示")
                        showSignUpPrompt = true
                        return
                    }
                    print("✅ 認証済み - デバイス登録確認表示")
                    showDeviceRegistrationConfirm = true
                }) {
                    HStack {
                        Image(systemName: "iphone")
                            .font(.title3)
                        Text("このデバイスで測定する")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.safeColor("AppAccentColor"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // 2. サンプルを見るボタン
                Button(action: {
                    // サンプルデバイスを選択
                    deviceManager.selectDevice(DeviceManager.sampleDeviceID)
                }) {
                    HStack {
                        Image(systemName: "eye")
                            .font(.title3)
                        Text("サンプルを見る")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(Color.safeColor("AppAccentColor"))
                    .cornerRadius(12)
                }

                // 3. QRコードでデバイスを追加ボタン
                Button(action: {
                    // ゲストモードチェック
                    if userAccountManager.requireAuthentication() {
                        showSignUpPrompt = true
                        return
                    }
                    showQRScanner = true
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                        Text("QRコードでデバイスを追加")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(Color.safeColor("AppAccentColor"))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - QRコードスキャン処理
    private func handleQRCodeScanned(_ code: String) async {
        // 既に追加済みかチェック
        if deviceManager.userDevices.contains(where: { $0.device_id == code }) {
            print("⚠️ このデバイスは既に追加されています")
            return
        }

        // デバイスを追加
        do {
            // ✅ CLAUDE.md: public.usersのuser_idを使用
            if let userId = userAccountManager.currentUser?.profile?.userId {
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
