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
    @State private var prefecture: String = ""
    @State private var city: String = ""
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
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteSuccessAlert = false
    
    // Avatar ViewModel
    @StateObject private var avatarViewModel = AvatarUploadViewModel(
        avatarType: .subject,
        entityId: "",  // 実際のIDはonAppearで設定
        authToken: nil
    )
    
    // Gender options
    private let genderOptions = ["男性", "女性", "その他", "回答しない"]

    // Prefecture options (47 prefectures of Japan)
    private let prefectureOptions = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
    
    // 編集モードかどうかの判定
    private var isEditing: Bool {
        editingSubject != nil
    }

    // View-only mode (based on device permissions)
    private var isViewOnly: Bool {
        // Get device from deviceManager
        guard let device = deviceManager.devices.first(where: { $0.device_id == deviceID }) else {
            return false
        }
        // If device cannot edit subject, this is view-only mode
        return !device.canEditSubject
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

                    // 削除ボタン（編集時かつ編集可能な場合のみ表示）
                    if isEditing && !isViewOnly {
                        deleteSection
                    }

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle(
                isViewOnly ? "観測対象の詳細" :
                isEditing ? "観測対象を編集" : "観測対象を追加"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isViewOnly ? "閉じる" : "キャンセル") {
                        dismiss()
                    }
                }

                // View-only mode: No save button
                if !isViewOnly {
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
            .alert("削除完了", isPresented: $showingDeleteSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("観測対象を削除しました。")
            }
            .alert("観測対象を削除", isPresented: $showingDeleteConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    Task {
                        await deleteSubject()
                    }
                }
            } message: {
                Text("この観測対象を完全に削除します。この操作は取り消せません。")
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

            VStack(spacing: 12) {
                // UserInfoViewと同じUIデザイン：アバター + 右下にカメラアイコン
                Button(action: {
                    if !isViewOnly {
                        showingAvatarPicker = true
                    }
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
                .disabled(!isEditing)
                .opacity(isEditing ? 1.0 : 0.5)

                // 新規登録時の説明テキスト
                if !isEditing {
                    Text("写真は登録完了後に設定できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        .disabled(isViewOnly)
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
                        .disabled(isViewOnly)
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
                    .disabled(isViewOnly)
                }

                // Prefecture (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("都道府県")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Button("選択しない") {
                            prefecture = ""
                        }

                        ForEach(prefectureOptions, id: \.self) { option in
                            Button(option) {
                                prefecture = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(prefecture.isEmpty ? "選択してください" : prefecture)
                                .foregroundColor(prefecture.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .disabled(isViewOnly)
                }

                // City (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("市区町村")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("例：横浜市", text: $city)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isViewOnly)
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
                    .disabled(isViewOnly)
            }
        }
    }

    // MARK: - Delete Section
    private var deleteSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 20)

            Text("危険な操作")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("観測対象を削除")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(8)
            }

            Text("この観測対象に関連する全てのデータが削除されます。この操作は取り消せません。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Data Loading
    private func loadEditingData() {
        if let subject = editingSubject {
            print("📖 Loading editing data for subject: \(subject.subjectId)")
            print("📖 Current subject data: name=\(subject.name ?? "nil"), age=\(subject.age?.description ?? "nil"), gender=\(subject.gender ?? "nil"), prefecture=\(subject.prefecture ?? "nil"), city=\(subject.city ?? "nil"), notes=\(subject.notes ?? "nil")")

            name = subject.name ?? ""
            age = subject.age != nil ? String(subject.age!) : ""
            gender = subject.gender ?? ""
            prefecture = subject.prefecture ?? ""
            city = subject.city ?? ""
            notes = subject.notes ?? ""

            print("📖 Form initialized: name=\(name), age=\(age), gender=\(gender), prefecture=\(prefecture), city=\(city), notes=\(notes)")

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
                prefecture: prefecture.isEmpty ? nil : prefecture,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city.trimmingCharacters(in: .whitespacesAndNewlines),
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

            // DeviceManagerのデータを強制的に再取得（最新のSubject情報を含む）
            if let userId = userAccountManager.currentUser?.id {
                await deviceManager.initializeDevices(for: userId)
            }

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
                deviceId: deviceID,
                name: trimmedName,
                age: ageInt,
                gender: gender.isEmpty ? nil : gender,
                prefecture: prefecture.isEmpty ? nil : prefecture,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city.trimmingCharacters(in: .whitespacesAndNewlines),
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

            // DeviceManagerのデータを強制的に再取得（最新のSubject情報を含む）
            if let userId = userAccountManager.currentUser?.id {
                await deviceManager.initializeDevices(for: userId)
            }

            print("✅ Subject update completed - name: \(trimmedName), age: \(ageInt?.description ?? "nil"), gender: \(gender.isEmpty ? "nil" : gender), notes: \(notes.isEmpty ? "nil" : notes)")

            await MainActor.run {
                isLoading = false
                // Always show success alert after successful update
                showingSuccessAlert = true
            }

        } catch {
            print("❌ Subject update error: \(error)")
            print("❌ Error details: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = "更新に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Subject Deletion
    private func deleteSubject() async {
        guard let subject = editingSubject else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // 観測対象を削除
            try await dataManager.deleteSubject(subjectId: subject.subjectId, deviceId: deviceID)

            // DeviceManagerのデータを強制的に再取得
            if let userId = userAccountManager.currentUser?.id {
                await deviceManager.initializeDevices(for: userId)
                print("✅ DeviceManager refreshed after subject deletion")
            }

            // 親ビューに観測対象が削除されたことを通知
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("SubjectUpdated"), object: nil)
            }

            print("✅ Subject deletion completed - subjectId: \(subject.subjectId)")

            await MainActor.run {
                isLoading = false
                showingDeleteSuccessAlert = true
            }

        } catch {
            print("❌ Subject deletion error: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = "削除に失敗しました: \(error.localizedDescription)"
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