//
//  ContentView.swift
//  ios_watchme_v9
//
//  シンプルな実装 - 日付変更バグ修正版
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    // シンプルな状態管理
    @State private var selectedDate: Date = Date()  // 初期値は現在時刻（後でonAppearで調整）
    @State private var showLogoutConfirmation = false
    @State private var showRecordingSheet = false
    
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
                    // ユーザーはデバイスを1つも連携していない
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("利用可能なデバイスがありません")
                            .font(.title3)
                            .foregroundColor(.primary)
                        Text("マイページからデバイスを連携してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
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
                                if let userId = authManager.currentUser?.id {
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
        .alert("ログアウト確認", isPresented: $showLogoutConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("本当にログアウトしますか？")
        }
        .onAppear {
            initializeNetworkManager()
            
            // デバイス初期化処理を呼び出す
            Task {
                if let userId = authManager.currentUser?.id {
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
        networkManager = NetworkManager(authManager: authManager, deviceManager: deviceManager)
        
        if let authUser = authManager.currentUser {
            networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
    }
}
