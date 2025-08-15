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
    @State private var selectedDate: Date = {
        // 初期値は今日の開始時刻（時間を00:00:00にリセット）
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date())
    }()
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
        
        return dates
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // ヘッダー（既存のHeaderViewを使用）
                    HeaderView(
                        showLogoutConfirmation: $showLogoutConfirmation,
                        showRecordingSheet: $showRecordingSheet
                    )
                    
                    // シンプルな日付ナビゲーション（スワイプと連動）
                    SimpleDateNavigation(selectedDate: $selectedDate)
                    
                    // TabViewでラップしてスワイプ対応
                    TabView(selection: $selectedDate) {
                        ForEach(dateRange, id: \.self) { date in
                            SimpleDashboardView(selectedDate: date)
                                .tag(date) // 日付を各ページに紐付け
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never)) // 横スワイプのスタイル、ドットは非表示
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
                                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                                
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
            // selectedDateがdateRangeに含まれていることを確認
            let calendar = deviceManager.deviceCalendar
            let normalizedDate = calendar.startOfDay(for: selectedDate)
            
            // 今日より未来の場合は今日に設定
            let today = calendar.startOfDay(for: Date())
            if normalizedDate > today {
                selectedDate = today
            } else {
                selectedDate = normalizedDate
            }
            
            // デバッグログ
            print("🔍 ContentView onAppear - selectedDate: \(selectedDate)")
            print("🔍 DateRange count: \(dateRange.count)")
            if let first = dateRange.first, let last = dateRange.last {
                print("🔍 DateRange: \(first) to \(last)")
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
                        .onChange(of: selectedDate) { oldValue, newValue in
                            // 日付が選択されたら自動的にシートを閉じる
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showDatePicker = false
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") {
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

