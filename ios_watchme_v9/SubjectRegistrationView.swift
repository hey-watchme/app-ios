//
//  SubjectRegistrationView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/30.
//

import SwiftUI
import PhotosUI

struct SubjectRegistrationView: View {
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var userAccountManager: UserAccountManager
    @Environment(\.dismiss) private var dismiss  // iOS 15+の推奨パターン
    
    let deviceID: String
    @Binding var isPresented: Bool  // 互換性のため残す
    let editingSubject: Subject? // 編集対象の観測対象（nilの場合は新規登録）
    
    // フォーム入力項目
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var notes: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showingAvatarPicker = false
    
    // UI状態
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showingSuccessAlert = false
    @State private var isUploadingAvatar = false
    
    // Avatar ViewModel
    @StateObject private var avatarViewModel = AvatarUploadViewModel(
        avatarType: .subject,
        entityId: "",  // 実際のIDはonAppearで設定
        authToken: nil
    )
    
    // 性別選択肢
    private let genderOptions = ["男性", "女性", "その他", "回答しない"]
    
    // 編集モードかどうかの判定
    private var isEditing: Bool {
        editingSubject != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // プロフィール写真
                    profileImageSection

                    // 基本情報
                    basicInfoSection

                    // メモ
                    notesSection

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle(isEditing ? "観測対象を編集" : "観測対象を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "更新" : "登録") {
                        Task {
                            if isEditing {
                                await updateSubject()
                            } else {
                                await registerSubject()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .onAppear {
                loadEditingData()
                // ViewModelの初期化
                avatarViewModel.entityId = editingSubject?.subjectId ?? ""
                avatarViewModel.authToken = userAccountManager.getAccessToken()
            }
            .alert(isEditing ? "更新完了" : "登録完了", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()  // iOS 15+の推奨パターン
                }
            } message: {
                Text(isEditing ? "観測対象の更新が完了しました。" : "観測対象の登録が完了しました。")
            }
            .alert("エラー", isPresented: .init(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK") { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(isEditing ? "更新中..." : "登録中...")
                                .font(.subheadline)
                        }
                        .padding(24)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Avatar Image View
    @ViewBuilder
    private var avatarImageView: some View {
        if let image = selectedImage {
            // 新規選択した画像を優先表示
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let subject = editingSubject {
            // 編集時：S3から表示（AvatarViewと同じロジック）
            let baseURL = AWSManager.shared.getAvatarURL(type: "subjects", id: subject.subjectId)
            let avatarURL = URL(string: "\(baseURL.absoluteString)?t=\(Date().timeIntervalSince1970)")
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_), .empty:
                    // デフォルトアイコン（グレー）
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.safeColor("BorderLight"))
                @unknown default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.safeColor("BorderLight"))
                }
            }
        } else {
            // 新規登録時：デフォルトアイコン（グレー）
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color.safeColor("BorderLight"))
        }
    }
    // MARK: - Profile Image Section
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            Text("プロフィール写真")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // UserInfoViewと同じUIデザイン：アバター + 右下にカメラアイコン
            Button(action: {
                showingAvatarPicker = true
            }) {
                ZStack(alignment: .bottomTrailing) {
                    // アバター画像表示
                    avatarImageView
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 4)
                        )

                    // カメラアイコンを追加（UserInfoViewと同じ）
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }
        }
        .sheet(isPresented: $showingAvatarPicker) {
            NavigationStack {
                AvatarPickerView(
                    viewModel: avatarViewModel,
                    currentAvatarURL: editingSubject != nil ? AWSManager.shared.getAvatarURL(type: "subjects", id: editingSubject!.subjectId) : nil
                )
                .navigationTitle("アバターを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showingAvatarPicker = false
                            avatarViewModel.reset()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        VStack(spacing: 20) {
            Text("基本情報")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // 名前（必須）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("名前")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("*")
                            .foregroundColor(Color.safeColor("ErrorColor"))
                        Spacer()
                    }
                    
                    TextField("例：田中太郎", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // 年齢（任意）
                VStack(alignment: .leading, spacing: 8) {
                    Text("年齢")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("例：25", text: $age)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                // 性別（任意）
                VStack(alignment: .leading, spacing: 8) {
                    Text("性別")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Menu {
                        Button("選択しない") {
                            gender = ""
                        }
                        
                        ForEach(genderOptions, id: \.self) { option in
                            Button(option) {
                                gender = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(gender.isEmpty ? "選択してください" : gender)
                                .foregroundColor(gender.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(spacing: 16) {
            Text("メモ")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("補足情報やその他のメモがあれば記入してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("例：趣味はランニング、朝型の生活リズム", text: $notes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadEditingData() {
        if let subject = editingSubject {
            name = subject.name ?? ""
            age = subject.age != nil ? String(subject.age!) : ""
            gender = subject.gender ?? ""
            notes = subject.notes ?? ""
            
            // S3からのアバター画像は、profileImageSectionのAsyncImageで直接表示されるため、
            // ここでは何もロードしない
        }
    }
    
    // MARK: - Subject Registration
    private func registerSubject() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名前を入力してください"
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 年齢の変換
            var ageInt: Int? = nil
            if !age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ageInt = Int(age.trimmingCharacters(in: .whitespacesAndNewlines))
                if ageInt == nil {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "年齢は数字で入力してください"
                    }
                    return
                }
            }
            
            // 現在のユーザーIDを取得
            guard let currentUser = userAccountManager.currentUser else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "ユーザー認証が必要です"
                }
                return
            }
            
            // 観測対象を登録（アバターURL無しで）
            let subjectId = try await dataManager.registerSubject(
                name: trimmedName,
                age: ageInt,
                gender: gender.isEmpty ? nil : gender,
                avatarUrl: nil, // S3アップロード後に更新するため、一旦null
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserId: currentUser.id
            )
            
            // アバター画像をアップロード
            if let image = selectedImage {
                await MainActor.run {
                    isUploadingAvatar = true
                }
                
                do {
                    // Supabase認証トークンを取得
                    let authToken = userAccountManager.getAccessToken()
                    
                    // ✅ Avatar Uploader APIを使用してS3にアップロード
                    let avatarUrl = try await AWSManager.shared.uploadAvatar(
                        image: image,
                        type: "subjects",
                        id: subjectId,
                        authToken: authToken
                    )
                    print("✅ Subject avatar uploaded to S3: \(avatarUrl)")
                    
                    // AvatarViewを更新
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("AvatarUpdated"), object: nil)
                        // アップロード成功後、選択画像をクリア（S3の画像を表示するため）
                        self.selectedImage = nil
                        self.selectedImageData = nil
                    }
                } catch {
                    print("❌ Avatar upload failed: \(error)")
                    // アバターアップロードに失敗しても、観測対象の登録は成功とする
                }
                
                await MainActor.run {
                    isUploadingAvatar = false
                }
            }
            
            // デバイスにsubject_idを設定
            try await dataManager.updateDeviceSubjectId(deviceId: deviceID, subjectId: subjectId)
            
            // データを再取得
            await dataManager.fetchAllReports(deviceId: deviceID, date: Date())
            
            await MainActor.run {
                isLoading = false
                showingSuccessAlert = true
            }
            
        } catch {
            print("❌ Subject registration error: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = "登録に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Subject Update
    private func updateSubject() async {
        guard let subject = editingSubject else { return }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名前を入力してください"
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 年齢の変換
            var ageInt: Int? = nil
            if !age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ageInt = Int(age.trimmingCharacters(in: .whitespacesAndNewlines))
                if ageInt == nil {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "年齢は数字で入力してください"
                    }
                    return
                }
            }
            
            // 観測対象を更新（アバターURL無しで）
            try await dataManager.updateSubject(
                subjectId: subject.subjectId,
                name: trimmedName,
                age: ageInt,
                gender: gender.isEmpty ? nil : gender,
                avatarUrl: nil, // S3のURLを使うため、DBにはnullを設定
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // アバター画像をアップロード
            if let image = selectedImage {
                await MainActor.run {
                    isUploadingAvatar = true
                }
                
                do {
                    // Supabase認証トークンを取得
                    let authToken = userAccountManager.getAccessToken()
                    
                    // ✅ Avatar Uploader APIを使用してS3にアップロード
                    let avatarUrl = try await AWSManager.shared.uploadAvatar(
                        image: image,
                        type: "subjects",
                        id: subject.subjectId,
                        authToken: authToken
                    )
                    print("✅ Subject avatar updated on S3: \(avatarUrl)")
                    
                    // AvatarViewを更新
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("AvatarUpdated"), object: nil)
                        // アップロード成功後、選択画像をクリア（S3の画像を表示するため）
                        self.selectedImage = nil
                        self.selectedImageData = nil
                    }
                } catch {
                    print("❌ Avatar upload failed: \(error)")
                    // アバターアップロードに失敗しても、観測対象の更新は成功とする
                }
                
                await MainActor.run {
                    isUploadingAvatar = false
                }
            }
            
            // データを再取得
            await dataManager.fetchAllReports(deviceId: deviceID, date: Date())
            
            await MainActor.run {
                isLoading = false
                // プロフィール更新の場合のみ成功アラートを表示
                if trimmedName != (editingSubject?.name ?? "") ||
                   ageInt != editingSubject?.age ||
                   (gender.isEmpty ? nil : gender) != editingSubject?.gender ||
                   (notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)) != editingSubject?.notes {
                    showingSuccessAlert = true
                }
            }
            
        } catch {
            print("❌ Subject update error: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = "更新に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let userAccountManager = UserAccountManager(deviceManager: deviceManager)
    
    return SubjectRegistrationView(
        deviceID: "sample-device-id",
        isPresented: .constant(true),
        editingSubject: nil
    )
    .environmentObject(SupabaseDataManager())
    .environmentObject(deviceManager)
    .environmentObject(userAccountManager)
}