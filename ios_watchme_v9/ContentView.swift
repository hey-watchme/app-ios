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
    
    // NetworkManagerの初期化（録音機能のため必要）
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var networkManager: NetworkManager?
    
    // TabView用の日付範囲（過去1年分）
    private var dateRange: [Date] {
        let calendar = deviceManager.deviceCalendar
        let today = calendar.startOfDay(for: Date())
        
        // 1年前の日付を取得
        guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
            return [today]
        }
        
        var dates: [Date] = []
        var currentDate = oneYearAgo
        
        // 1年前から今日までの日付の配列を生成
        while currentDate <= today {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // 最後の要素（今日）が確実に含まれるようにする
        if let lastDate = dates.last, !calendar.isDate(lastDate, inSameDayAs: today) {
            dates.append(today)
        }
        
        return dates
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ヘッダー（既存のHeaderViewを使用）
                HeaderView(
                    showLogoutConfirmation: $showLogoutConfirmation,
                    showRecordingSheet: $showRecordingSheet
                )
                
                // DeviceManagerの状態に応じた表示制御
                switch deviceManager.state {
                case .idle, .loading:
                    // 状態が「初期状態」または「ロード中」ならスピナーを表示
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
                    
                case .ready:
                    // 準備完了！ここで初めてダッシュボード本体を表示
                    ZStack(alignment: .top) {
                        // TabViewでラップしてスワイプ対応
                        TabView(selection: $selectedDate) {
                            ForEach(dateRange, id: \.self) { date in
                                SimpleDashboardView(
                                    selectedDate: $selectedDate
                                )
                                .tag(date) // 日付を各ページに紐付け
                            }
                        }
                        .id(deviceManager.selectedDeviceID) // デバイスが変わったらTabViewを再構築
                        .tabViewStyle(.page(indexDisplayMode: .never)) // 横スワイプのスタイル、ドットは非表示
                    }
                    .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
                        // デバイスが切り替わったら日付を今日（配列の最後）にリセット
                        if oldValue != newValue && newValue != nil {
                            // dateRangeの最後の要素（今日）を取得
                            if let todayDate = dateRange.last {
                                // TabViewを確実に更新するため、少し遅延を入れる
                                Task { @MainActor in
                                    selectedDate = todayDate
                                    print("📅 ContentView: Device changed, resetting date to last element (today): \(todayDate)")
                                    print("📅 Index in dateRange: \(dateRange.firstIndex(of: todayDate) ?? -1) of \(dateRange.count)")
                                }
                            }
                        }
                    }
                    
                case .noDevices:
                    // デバイスがない時のUI
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
                                if let userId = userAccountManager.currentUser?.profile?.userId {
                                    await deviceManager.initializeDeviceState(for: userId)
                                }
                            }
                        }) {
                            Text("リトライ")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.safeColor("PrimaryActionColor"))
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
        .onAppear {
            initializeNetworkManager()

            // デバイス初期化処理を呼び出す
            Task {
                // ✅ CLAUDE.md: public.usersのuser_idを使用
                if let userId = userAccountManager.currentUser?.profile?.userId {
                    await deviceManager.initializeDeviceState(for: userId)
                }
            }
            
            // 日付を今日に設定（初期表示時）- 最後の要素を使用
            if let todayDate = dateRange.last {
                selectedDate = todayDate
                print("🔍 ContentView onAppear - selectedDate set to last element (today): \(todayDate)")
            } else {
                let calendar = deviceManager.deviceCalendar
                let today = calendar.startOfDay(for: Date())
                selectedDate = today
                print("🔍 ContentView onAppear - selectedDate set to today: \(selectedDate)")
            }
            
            // デバッグログ
            print("🔍 DateRange count: \(dateRange.count)")
            if let first = dateRange.first, let last = dateRange.last {
                print("🔍 DateRange: \(first) to \(last)")
                print("🔍 Selected date index: \(dateRange.firstIndex(of: selectedDate) ?? -1)")
            }
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
            // DeviceManagerのregisterDeviceメソッドを呼び出す
            await MainActor.run {
                deviceManager.registerDevice(userId: userId)
            }

            // 登録完了まで待機（最大5秒）
            var attempts = 0
            while deviceManager.isLoading && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                attempts += 1
            }

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
}
