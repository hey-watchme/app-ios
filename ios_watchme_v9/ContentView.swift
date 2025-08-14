//
//  ContentView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showUserIDChangeAlert = false
    @State private var newUserID = ""
    @State private var showLogoutConfirmation = false
    @State private var networkManager: NetworkManager?
    @State private var showRecordingSheet = false
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    @State private var selectedDeviceForSubject: String? = nil
    @State private var editingSubject: Subject? = nil
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var showDeviceSelection = false
    
    // 日付の選択状態を一元管理
    @State private var selectedDate = Date()
    // TabViewの選択状態を管理（ダッシュボードから開始）
    @State private var selectedTab = 0
    
    // DashboardViewModelを生成・管理
    @State private var dashboardViewModel: DashboardViewModel?
    
    // DatePickerの表示状態
    @State private var showDatePicker = false
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    private func initializeNetworkManager() {
        networkManager = NetworkManager(authManager: authManager, deviceManager: deviceManager)
        
        if let authUser = authManager.currentUser {
            networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
        print("🔧 NetworkManager初期化完了")
    }
    
    var body: some View {
        if let networkManager = networkManager {
            NavigationStack {
                VStack(spacing: 0) { // ヘッダー、日付ナビゲーション、TabViewを縦に並べる
                // 固定ヘッダー (デバイス選択、ユーザー情報、通知など)
                HStack {
                    // デバイス選択ボタン
                    Button(action: {
                        showDeviceSelection = true
                    }) {
                        HStack {
                            Image(systemName: deviceManager.userDevices.isEmpty ? "iphone.slash" : "iphone")
                            Text(deviceManager.userDevices.isEmpty ? "デバイス連携: なし" : deviceManager.selectedDeviceID?.prefix(8) ?? "デバイス未選択")
                        }
                        .font(.subheadline)
                        .foregroundColor(deviceManager.userDevices.isEmpty ? .orange : .blue)
                    }
                    
                    Spacer()
                    
                    // ユーザー情報/通知 (仮)
                    NavigationLink(destination: 
                        UserInfoView(
                            authManager: authManager,
                            deviceManager: deviceManager,
                            showLogoutConfirmation: $showLogoutConfirmation
                        )
                        .environmentObject(dataManager)
                        .environmentObject(deviceManager)
                        .environmentObject(authManager)
                    ) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).shadow(radius: 1))
                
                // 日付ナビゲーション
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showDatePicker = true
                    }) {
                        VStack(spacing: 4) {
                            Text(dateFormatter.string(from: selectedDate))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if Calendar.current.isDateInToday(selectedDate) {
                                Text("今日")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            if tomorrow <= Date() {
                                selectedDate = tomorrow
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
                
                TabView(selection: $selectedTab) {
                    // ダッシュボードタブ
                    NavigationView {
                        if let viewModel = dashboardViewModel {
                            DashboardView(viewModel: viewModel, selectedTab: $selectedTab)
                        } else {
                            ProgressView("初期化中...")
                        }
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("ダッシュボード", systemImage: "square.grid.2x2")
                    }
                    .tag(0)
                    
                    // 心理グラフタブ (Vibe Graph)
                    NavigationView {
                        HomeView() // 引数を削除
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("心理グラフ", systemImage: "brain")
                    }
                    .tag(1)
                    
                    // 行動グラフタブ (Behavior Graph)
                    NavigationView {
                        BehaviorGraphView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("行動グラフ", systemImage: "figure.walk.motion")
                    }
                    .tag(2)
                    
                    // 感情グラフタブ (Emotion Graph)
                    NavigationView {
                        EmotionGraphView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("感情グラフ", systemImage: "heart.text.square")
                    }
                    .tag(3)
                    
                    // 録音タブ（タップでモーダル表示）
                    Text("")
                        .tabItem {
                            Label("録音", systemImage: "mic.circle.fill")
                        }
                        .tag(4)
                        .onAppear {
                            if selectedTab == 4 {
                                showRecordingSheet = true
                                // タブを前の位置に戻す
                                selectedTab = 0
                            }
                        }
                }
            }
            .alert("通知", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("ユーザーID変更", isPresented: $showUserIDChangeAlert) {
                TextField("新しいユーザーID", text: $newUserID)
                Button("変更") {
                    if !newUserID.isEmpty {
                        networkManager.setUserID(newUserID)
                        alertMessage = "ユーザーIDを変更しました: \(newUserID)"
                        showAlert = true
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("新しいユーザーIDを入力してください")
            }
            .confirmationDialog("ログアウト確認", isPresented: $showLogoutConfirmation) {
                Button("ログアウト", role: .destructive) {
                    // ログアウト処理を非同期で実行
                    Task {
                        // まずログアウト処理を実行
                        authManager.signOut()
                        
                        // ネットワークマネージャーのリセット
                        networkManager.resetToFallbackUserID()
                        
                        // データマネージャーのクリア
                        dataManager.clearData()
                        
                        // デバイスマネージャーのクリア
                        deviceManager.userDevices = []
                        deviceManager.selectedDeviceID = nil
                        
                        // 少し待ってから通知を表示（UIの更新を確実にするため）
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                        
                        await MainActor.run {
                            alertMessage = "ログアウトしました"
                            showAlert = true
                        }
                    }
                }
            } message: {
                Text("本当にログアウトしますか？")
            }
            .sheet(isPresented: $showDeviceSelection, onDismiss: {
                loadSubjectsForAllDevices()
            }) {
                DeviceSelectionView(isPresented: $showDeviceSelection, subjectsByDevice: $subjectsByDevice)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .environmentObject(authManager)
                    .onAppear {
                        loadSubjectsForAllDevices()
                    }
            }
            .sheet(isPresented: $showSubjectRegistration, onDismiss: {
                loadSubjectsForAllDevices()
            }) {
                if let deviceID = selectedDeviceForSubject {
                    SubjectRegistrationView(
                        deviceID: deviceID,
                        isPresented: $showSubjectRegistration,
                        editingSubject: nil
                    )
                    .environmentObject(dataManager)
                    .environmentObject(deviceManager)
                    .environmentObject(authManager)
                }
            }
            .sheet(isPresented: $showSubjectEdit, onDismiss: {
                loadSubjectsForAllDevices()
            }) {
                if let deviceID = selectedDeviceForSubject,
                   let subject = editingSubject {
                    SubjectRegistrationView(
                        deviceID: deviceID,
                        isPresented: $showSubjectEdit,
                        editingSubject: subject
                    )
                    .environmentObject(dataManager)
                    .environmentObject(deviceManager)
                    .environmentObject(authManager)
                }
            }
            .sheet(isPresented: $showRecordingSheet) {
                NavigationView {
                    RecordingView(audioRecorder: audioRecorder, networkManager: networkManager)
                        .navigationTitle("録音")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    showRecordingSheet = false
                                }) {
                                    Text("閉じる")
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    VStack {
                        DatePicker(
                            "日付を選択",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .padding()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        
                        Spacer()
                    }
                    .navigationTitle("日付を選択")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("キャンセル") {
                                showDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完了") {
                                showDatePicker = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .onChange(of: networkManager.connectionStatus) { oldValue, newValue in
                // アップロード完了時の通知
                if newValue == .connected && networkManager.currentUploadingFile != nil {
                    alertMessage = "アップロードが完了しました！"
                    showAlert = true
                } else if newValue == .failed && networkManager.currentUploadingFile != nil {
                    alertMessage = "アップロードに失敗しました。手動でリトライしてください。"
                    showAlert = true
                }
            }
            // selectedDate または selectedDeviceID が変更されたときにデータをフェッチ
            .onChange(of: selectedDate) { oldValue, newValue in
                // DashboardViewModelにも日付変更を通知
                dashboardViewModel?.updateSelectedDate(newValue)
            }
            .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
                // ViewModelが自身のPublisherで検知するため、ここでの処理は不要
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 4 {
                    showRecordingSheet = true
                    // すぐに前のタブに戻す
                    selectedTab = oldValue
                }
            }
            .onAppear {
                initializeNetworkManager()
                // DashboardViewModelを初期化
                if dashboardViewModel == nil {
                    dashboardViewModel = DashboardViewModel(
                        dataManager: dataManager,
                        deviceManager: deviceManager,
                        initialDate: selectedDate
                    )
                }
                // ViewModelのonAppearを呼び出す
                dashboardViewModel?.onAppear()
            }
            }
        } else {
            ProgressView("初期化中...")
                .onAppear {
                    initializeNetworkManager()
                }
        }
    }
    
    // MARK: - Private Methods
    
    private var canGoToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        return tomorrow <= Date()
    }
    
    private func loadSubjectsForAllDevices() {
        Task {
            var newSubjects: [String: Subject] = [:]
            
            for device in deviceManager.userDevices {
                // 各デバイスの観測対象を取得
                await dataManager.fetchSubjectForDevice(deviceId: device.device_id)
                if let subject = dataManager.subject {
                    newSubjects[device.device_id] = subject
                }
            }
            
            await MainActor.run {
                self.subjectsByDevice = newSubjects
            }
        }
    }
}

// MARK: - ユーザー情報ビュー
struct UserInfoView: View {
    let authManager: SupabaseAuthManager
    let deviceManager: DeviceManager
    @Binding var showLogoutConfirmation: Bool
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    @State private var selectedDeviceForSubject: String? = nil
    @State private var editingSubject: Subject? = nil
    @State private var showAvatarPicker = false
    @State private var isUploadingAvatar = false
    @State private var avatarUploadError: String? = nil
    @EnvironmentObject var dataManager: SupabaseDataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ユーザーアバター編集可能なセクション
                VStack(spacing: 12) {
                    AvatarView(userId: authManager.currentUser?.id)
                        .padding(.top, 20)
                    
                    Button(action: {
                        showAvatarPicker = true
                    }) {
                        Label("アバターを編集", systemImage: "pencil.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .disabled(isUploadingAvatar)
                    
                    if isUploadingAvatar {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    
                    if let error = avatarUploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // ユーザー情報セクション
                VStack(spacing: 16) {
                    // ユーザーアカウント情報
                    InfoSection(title: "ユーザーアカウント情報") {
                        if let user = authManager.currentUser {
                            // 名前（profile.nameから取得）
                            if let profile = user.profile, let name = profile.name {
                                InfoRowTwoLine(label: "名前", value: name, icon: "person.fill")
                            }
                            
                            InfoRowTwoLine(label: "メールアドレス", value: user.email, icon: "envelope.fill")
                            
                            // ニュースレター配信設定（会員登録日より上に配置）
                            if let profile = user.profile {
                                let newsletterStatus = profile.newsletter == true ? "ON" : "OFF"
                                InfoRow(label: "ニュースレター配信", value: newsletterStatus, icon: "envelope.badge", valueColor: profile.newsletter == true ? .green : .secondary)
                                
                                // 会員登録日
                                if let createdAt = profile.createdAt {
                                    let formattedDate = formatDate(createdAt)
                                    InfoRow(label: "会員登録日", value: formattedDate, icon: "calendar.badge.plus")
                                }
                            }
                            
                            InfoRowTwoLine(label: "ユーザーID", value: user.id, icon: "person.text.rectangle.fill")
                        } else {
                            InfoRow(label: "状態", value: "ログインしていません", icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                    
                    // デバイス情報
                    InfoSection(title: "デバイス情報") {
                        // ユーザーのデバイス一覧
                        if deviceManager.isLoading {
                            InfoRow(label: "状態", value: "デバイス情報を取得中...", icon: "arrow.clockwise", valueColor: .orange)
                        } else if !deviceManager.userDevices.isEmpty {
                            // DeviceSectionViewを使用
                            DeviceSectionView(
                                devices: deviceManager.userDevices,
                                selectedDeviceID: deviceManager.selectedDeviceID,
                                subjectsByDevice: subjectsByDevice,
                                showSelectionUI: false,
                                isCompact: false,
                                onEditSubject: { deviceId, subject in
                                    selectedDeviceForSubject = deviceId
                                    editingSubject = subject
                                    showSubjectEdit = true
                                },
                                onAddSubject: { deviceId in
                                    selectedDeviceForSubject = deviceId
                                    editingSubject = nil
                                    showSubjectRegistration = true
                                }
                            )
                        } else {
                            VStack(spacing: 12) {
                                InfoRow(label: "状態", value: "デバイスが連携されていません", icon: "iphone.slash", valueColor: .orange)
                                
                                Button(action: {
                                    // デバイス連携処理を実行
                                    if let userId = authManager.currentUser?.id {
                                        deviceManager.registerDevice(userId: userId)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "link.circle.fill")
                                        Text("このデバイスを連携")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(deviceManager.isLoading)
                            }
                        }
                        
                        // デバイス登録エラー表示
                        if let error = deviceManager.registrationError {
                            InfoRow(label: "エラー", value: error, icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                }
                
                Spacer()
                
                // ログアウトボタン
                if authManager.isAuthenticated {
                    Button(action: {
                        dismiss()
                        // シートが完全に閉じてからダイアログを表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showLogoutConfirmation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            Text("ログアウト")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("マイページ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
                // デバイス情報を再取得
                if deviceManager.userDevices.isEmpty, let userId = authManager.currentUser?.id {
                    print("📱 UserInfoSheet: デバイス情報を取得")
                    Task {
                        await deviceManager.fetchUserDevices(for: userId)
                    }
                }
                // 観測対象情報を読み込み
                loadSubjectsForAllDevices()
            }
        .sheet(isPresented: $showSubjectRegistration, onDismiss: {
            loadSubjectsForAllDevices()
        }) {
            if let deviceID = selectedDeviceForSubject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectRegistration,
                    editingSubject: nil
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showSubjectEdit, onDismiss: {
            loadSubjectsForAllDevices()
        }) {
            if let deviceID = selectedDeviceForSubject,
               let subject = editingSubject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectEdit,
                    editingSubject: subject
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            NavigationView {
                VStack {
                    AvatarPickerView(
                        currentAvatarURL: getAvatarURL(),
                        onImageSelected: { image in
                            uploadAvatar(image: image)
                        },
                        onDelete: nil // ユーザーアバターの削除は現時点では実装しない
                    )
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("アバターを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showAvatarPicker = false
                        }
                    }
                }
            }
        }
    }
    
    private func loadSubjectsForAllDevices() {
        Task {
            var newSubjects: [String: Subject] = [:]
            
            for device in deviceManager.userDevices {
                // 各デバイスの観測対象を取得
                await dataManager.fetchSubjectForDevice(deviceId: device.device_id)
                if let subject = dataManager.subject {
                    newSubjects[device.device_id] = subject
                }
            }
            
            await MainActor.run {
                self.subjectsByDevice = newSubjects
            }
        }
    }
    
    // MARK: - Avatar Helper Methods
    
    private func getAvatarURL() -> URL? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return AWSManager.shared.getAvatarURL(type: "users", id: userId)
    }
    
    private func uploadAvatar(image: UIImage) {
        guard let userId = authManager.currentUser?.id else { 
            print("❌ User ID not found")
            return 
        }
        
        print("🚀 Starting avatar upload for user: \(userId)")
        print("📐 Image size: \(image.size), Scale: \(image.scale)")
        
        isUploadingAvatar = true
        avatarUploadError = nil
        showAvatarPicker = false
        
        Task {
            do {
                // ✅ Avatar Uploader APIを使用してS3にアップロード
                let url = try await AWSManager.shared.uploadAvatar(
                    image: image,
                    type: "users",
                    id: userId
                )
                
                await MainActor.run {
                    isUploadingAvatar = false
                    // AvatarViewを強制的に更新
                    NotificationCenter.default.post(name: NSNotification.Name("AvatarUpdated"), object: nil)
                    print("✅ アバターアップロード成功: \(url)")
                    
                    // 成功メッセージを表示（オプション）
                    // TODO: アラートやトーストで成功を通知
                }
            } catch {
                await MainActor.run {
                    isUploadingAvatar = false
                    avatarUploadError = error.localizedDescription
                    print("❌ アバターアップロードエラー: \(error)")
                    print("📝 Error details: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 情報セクション
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - 情報行
struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - 2行表示情報行
struct InfoRowTwoLine: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - アバタービュー
struct AvatarView: View {
    let userId: String?
    let size: CGFloat = 80
    let useS3: Bool = true // ✅ Avatar Uploader APIを使用してS3に保存
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var avatarUrl: URL?
    @State private var isLoadingAvatar = true
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        Group {
            if isLoadingAvatar {
                // 読み込み中
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: size, height: size)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            } else if let url = avatarUrl {
                // アバター画像を表示
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    case .failure(_):
                        // エラー時のデフォルトアイコン
                        defaultAvatarView
                    case .empty:
                        // 読み込み中
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: size, height: size)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    @unknown default:
                        defaultAvatarView
                    }
                }
            } else {
                // アバター未設定時のデフォルトアイコン
                defaultAvatarView
            }
        }
        .onAppear {
            loadAvatar()
        }
        .onChange(of: userId) { oldValue, newValue in
            loadAvatar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AvatarUpdated"))) { _ in
            // アバターが更新されたら再読み込み
            lastUpdateTime = Date()
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        Task {
            guard let userId = userId else {
                print("⚠️ ユーザーIDが指定されていません")
                isLoadingAvatar = false
                return
            }
            
            isLoadingAvatar = true
            
            if useS3 {
                // S3のURLを設定（Avatar Uploader API経由でアップロード済み）
                let baseURL = AWSManager.shared.getAvatarURL(type: "users", id: userId)
                let timestamp = Int(lastUpdateTime.timeIntervalSince1970)
                self.avatarUrl = URL(string: "\(baseURL.absoluteString)?t=\(timestamp)")
                print("🌐 Loading avatar from S3: \(self.avatarUrl?.absoluteString ?? "nil")")
            } else {
                // Supabaseから取得（既存の実装）
                self.avatarUrl = await dataManager.fetchAvatarUrl(for: userId)
            }
            
            self.isLoadingAvatar = false
        }
    }
    
    private var defaultAvatarView: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: size))
            .foregroundColor(.blue)
    }
}

// MARK: - ヘルパー関数
private func formatDate(_ dateString: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    // ISO8601形式でパースを試行
    if let date = isoFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // フォールバック: 別の形式を試行
    let fallbackFormatter = DateFormatter()
    fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
    if let date = fallbackFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // 最終的にフォーマットできない場合は元の文字列を返す
    return dateString
}

#Preview {
    ContentView()
}
