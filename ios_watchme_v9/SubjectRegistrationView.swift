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
    @EnvironmentObject var authManager: SupabaseAuthManager
    
    let deviceID: String
    @Binding var isPresented: Bool
    let editingSubject: Subject? // 編集対象の観測対象（nilの場合は新規登録）
    
    // フォーム入力項目
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var notes: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    // UI状態
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showingSuccessAlert = false
    
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
                    // ヘッダー
                    headerSection
                    
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
            .navigationTitle(isEditing ? "観測対象の編集" : "観測対象の登録")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
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
            }
            .alert(isEditing ? "更新完了" : "登録完了", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    isPresented = false
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(isEditing ? "観測対象のプロフィールを編集" : "観測対象のプロフィールを登録")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(isEditing ? "観測対象の基本情報を編集してください" : "このデバイスで観測する人物の基本情報を入力してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Profile Image Section
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            Text("プロフィール写真")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                // 写真表示
                Group {
                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo")
                            Text("写真を選択")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if selectedImageData != nil {
                        Button("削除") {
                            selectedItem = nil
                            selectedImageData = nil
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    selectedImageData = data
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
                            .foregroundColor(.red)
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
            
            // アバター画像の読み込み
            if let avatarUrlString = subject.avatarUrl,
               avatarUrlString.hasPrefix("data:image"),
               let imageData = Data(base64Encoded: String(avatarUrlString.dropFirst(22)), options: .ignoreUnknownCharacters) {
                selectedImageData = imageData
            }
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
            
            // アバター画像の処理
            var avatarUrl: String? = nil
            if let imageData = selectedImageData {
                // Base64エンコード
                let base64String = imageData.base64EncodedString()
                avatarUrl = "data:image/jpeg;base64,\(base64String)"
            }
            
            // 現在のユーザーIDを取得
            guard let currentUser = authManager.currentUser else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "ユーザー認証が必要です"
                }
                return
            }
            
            // 観測対象を登録
            let subjectId = try await dataManager.registerSubject(
                name: trimmedName,
                age: ageInt,
                gender: gender.isEmpty ? nil : gender,
                avatarUrl: avatarUrl,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserId: currentUser.id
            )
            
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
            
            // アバター画像の処理
            var avatarUrl: String? = nil
            if let imageData = selectedImageData {
                // Base64エンコード
                let base64String = imageData.base64EncodedString()
                avatarUrl = "data:image/jpeg;base64,\(base64String)"
            }
            
            // 観測対象を更新
            try await dataManager.updateSubject(
                subjectId: subject.subjectId,
                name: trimmedName,
                age: ageInt,
                gender: gender.isEmpty ? nil : gender,
                avatarUrl: avatarUrl,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // データを再取得
            await dataManager.fetchAllReports(deviceId: deviceID, date: Date())
            
            await MainActor.run {
                isLoading = false
                showingSuccessAlert = true
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
    let authManager = SupabaseAuthManager(deviceManager: deviceManager)
    
    return SubjectRegistrationView(
        deviceID: "sample-device-id",
        isPresented: .constant(true),
        editingSubject: nil
    )
    .environmentObject(SupabaseDataManager())
    .environmentObject(deviceManager)
    .environmentObject(authManager)
}