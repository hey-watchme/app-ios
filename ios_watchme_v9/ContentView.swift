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
    @State private var selectedDate = Date()
    @State private var selectedTab = 0
    @State private var showDeviceSelection = false
    @State private var showLogoutConfirmation = false
    @State private var showRecordingSheet = false
    
    // NetworkManagerの初期化（録音機能のため必要）
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var networkManager: NetworkManager?
    @State private var subjectsByDevice: [String: Subject] = [:]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー（既存のHeaderViewを使用）
                HeaderView(
                    showDeviceSelection: $showDeviceSelection,
                    showLogoutConfirmation: $showLogoutConfirmation
                )
                
                // シンプルな日付ナビゲーション
                SimpleDateNavigation(selectedDate: $selectedDate)
                
                // タブビュー（DatePagingViewを使わない）
                TabView(selection: $selectedTab) {
                    // ダッシュボード（シンプル版）
                    SimpleDashboardView(selectedDate: selectedDate, selectedTab: $selectedTab)
                        .tabItem {
                            Label("ダッシュボード", systemImage: "square.grid.2x2")
                        }
                        .tag(0)
                    
                    // 心理グラフ
                    SimpleVibeView(selectedDate: selectedDate)
                        .tabItem {
                            Label("心理グラフ", systemImage: "brain")
                        }
                        .tag(1)
                    
                    // 行動グラフ
                    SimpleBehaviorView(selectedDate: selectedDate)
                        .tabItem {
                            Label("行動グラフ", systemImage: "figure.walk.motion")
                        }
                        .tag(2)
                    
                    // 感情グラフ
                    SimpleEmotionView(selectedDate: selectedDate)
                        .tabItem {
                            Label("感情グラフ", systemImage: "heart.text.square")
                        }
                        .tag(3)
                    
                    // 録音タブ
                    Text("")
                        .tabItem {
                            Label("録音", systemImage: "mic.circle.fill")
                        }
                        .tag(4)
                        .onAppear {
                            if selectedTab == 4 {
                                showRecordingSheet = true
                                selectedTab = 0
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showDeviceSelection) {
            DeviceSelectionView(isPresented: $showDeviceSelection, subjectsByDevice: $subjectsByDevice)
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

// シンプルな日付ナビゲーション
struct SimpleDateNavigation: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showDatePicker = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter
    }
    
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    private var canGoToNextDay: Bool {
        !calendar.isDateInToday(selectedDate)
    }
    
    var body: some View {
        HStack {
            // 前日ボタン
            Button(action: {
                withAnimation {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // 日付表示とピッカー
            Button(action: {
                showDatePicker = true
            }) {
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if calendar.isDateInToday(selectedDate) {
                        Text("今日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    DatePicker("日付を選択", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("日付を選択")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完了") {
                                    showDatePicker = false
                                }
                            }
                        }
                }
            }
            
            Spacer()
            
            // 翌日ボタン
            Button(action: {
                withAnimation {
                    if canGoToNextDay {
                        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(canGoToNextDay ? .blue : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoToNextDay)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).shadow(radius: 1))
    }
}

// シンプルな心理グラフビュー
struct SimpleVibeView: View {
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    @State private var vibeReport: DailyVibeReport?
    @State private var subject: Subject?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack {
                if isLoading {
                    ProgressView("読み込み中...")
                        .padding()
                } else if let report = vibeReport {
                    HomeView(vibeReport: report, subject: subject)
                } else {
                    Text("データがありません")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .task(id: selectedDate) {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let timezone = deviceManager.getTimezone(for: deviceId)
        let result = await dataManager.fetchAllReports(
            deviceId: deviceId,
            date: selectedDate,
            timezone: timezone
        )
        
        self.vibeReport = result.vibeReport
        self.subject = result.subject
    }
}

// シンプルな行動グラフビュー
struct SimpleBehaviorView: View {
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    @State private var behaviorReport: BehaviorReport?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack {
                if isLoading {
                    ProgressView("読み込み中...")
                        .padding()
                } else if let report = behaviorReport {
                    BehaviorGraphView(behaviorReport: report)
                } else {
                    Text("データがありません")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .task(id: selectedDate) {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let timezone = deviceManager.getTimezone(for: deviceId)
        let result = await dataManager.fetchAllReports(
            deviceId: deviceId,
            date: selectedDate,
            timezone: timezone
        )
        
        self.behaviorReport = result.behaviorReport
    }
}

// シンプルな感情グラフビュー
struct SimpleEmotionView: View {
    let selectedDate: Date
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    
    @State private var emotionReport: EmotionReport?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack {
                if isLoading {
                    ProgressView("読み込み中...")
                        .padding()
                } else if let report = emotionReport {
                    EmotionGraphView(emotionReport: report)
                } else {
                    Text("データがありません")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .task(id: selectedDate) {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let timezone = deviceManager.getTimezone(for: deviceId)
        let result = await dataManager.fetchAllReports(
            deviceId: deviceId,
            date: selectedDate,
            timezone: timezone
        )
        
        self.emotionReport = result.emotionReport
    }
}