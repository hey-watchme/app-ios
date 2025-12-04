//
//  SubjectFormModel.swift
//  ios_watchme_v9
//
//  Refactored model for subject registration/editing
//  Separates data logic from UI for better performance
//

import SwiftUI
import Foundation

/// Constants for the form
enum SubjectFormConstants {
    static let genderOptions = ["男性", "女性", "その他", "回答しない"]
    static let prefectureOptions = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
}

/// Form data model
struct SubjectFormData {
    var name: String = ""
    var age: String = ""
    var gender: String = ""
    var prefecture: String = ""
    var city: String = ""
    var notes: String = ""
    var selectedImage: UIImage? = nil

    init() {}

    init(from subject: Subject) {
        self.name = subject.name ?? ""
        self.age = subject.age != nil ? String(subject.age!) : ""
        self.gender = subject.gender ?? ""
        self.prefecture = subject.prefecture ?? ""
        self.city = subject.city ?? ""
        self.notes = subject.notes ?? ""
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ageInt: Int? {
        let trimmed = age.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }
}

/// View Model for Subject Form
@MainActor
class SubjectFormViewModel: ObservableObject {
    // Form data
    @Published var formData = SubjectFormData()

    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSuccessAlert = false
    @Published var showingDeleteConfirmation = false

    // Dependencies (injected)
    private let deviceID: String
    private let editingSubject: Subject?
    private weak var dataManager: SupabaseDataManager?
    private weak var deviceManager: DeviceManager?
    private weak var userAccountManager: UserAccountManager?

    // Cached values to avoid recomputation
    private(set) var isEditing: Bool
    private(set) var isViewOnly: Bool

    init(
        deviceID: String,
        editingSubject: Subject?,
        dataManager: SupabaseDataManager,
        deviceManager: DeviceManager,
        userAccountManager: UserAccountManager
    ) {
        self.deviceID = deviceID
        self.editingSubject = editingSubject
        self.dataManager = dataManager
        self.deviceManager = deviceManager
        self.userAccountManager = userAccountManager

        // Pre-calculate these values once
        self.isEditing = editingSubject != nil

        // Calculate view-only status once
        if let device = deviceManager.devices.first(where: { $0.device_id == deviceID }) {
            self.isViewOnly = !device.canEditSubject
        } else {
            self.isViewOnly = false
        }

        // Load data if editing
        if let subject = editingSubject {
            self.formData = SubjectFormData(from: subject)
        }
    }

    // MARK: - Actions

    func save() async {
        guard formData.isValid else {
            errorMessage = "名前を入力してください"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            if isEditing {
                await updateSubject()
            } else {
                await createSubject()
            }

            // Refresh devices
            if let userId = userAccountManager?.currentUser?.id {
                await deviceManager?.initializeDevices(for: userId)
            }

            isLoading = false
            showingSuccessAlert = true

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func createSubject() async {
        guard let currentUser = userAccountManager?.currentUser else {
            errorMessage = "ユーザー認証が必要です"
            return
        }

        do {
            let subjectId = try await dataManager?.registerSubject(
                name: formData.name,
                age: formData.ageInt,
                gender: formData.gender.isEmpty ? nil : formData.gender,
                prefecture: formData.prefecture.isEmpty ? nil : formData.prefecture,
                city: formData.city.isEmpty ? nil : formData.city,
                avatarUrl: nil,
                notes: formData.notes.isEmpty ? nil : formData.notes,
                createdByUserId: currentUser.id
            )

            // Upload avatar if selected
            if let image = formData.selectedImage, let subjectId = subjectId {
                await uploadAvatar(image: image, subjectId: subjectId)
            }

            // Set device subject ID
            if let subjectId = subjectId {
                try await dataManager?.updateDeviceSubjectId(
                    deviceId: deviceID,
                    subjectId: subjectId
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSubject() async {
        guard let subject = editingSubject else { return }

        do {
            try await dataManager?.updateSubject(
                subjectId: subject.subjectId,
                deviceId: deviceID,
                name: formData.name,
                age: formData.ageInt,
                gender: formData.gender.isEmpty ? nil : formData.gender,
                prefecture: formData.prefecture.isEmpty ? nil : formData.prefecture,
                city: formData.city.isEmpty ? nil : formData.city,
                avatarUrl: nil,
                notes: formData.notes.isEmpty ? nil : formData.notes
            )

            // Upload avatar if changed
            if let image = formData.selectedImage {
                await uploadAvatar(image: image, subjectId: subject.subjectId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadAvatar(image: UIImage, subjectId: String) async {
        do {
            let authToken = userAccountManager?.getAccessToken()
            let avatarUrl = try await AWSManager.shared.uploadAvatar(
                image: image,
                type: "subjects",
                id: subjectId,
                authToken: authToken
            )
            print("✅ Avatar uploaded: \(avatarUrl)")

            // Clear selected image after successful upload
            formData.selectedImage = nil

            // Notify avatar update
            NotificationCenter.default.post(name: NSNotification.Name("AvatarUpdated"), object: nil)
        } catch {
            print("❌ Avatar upload failed: \(error)")
            // Don't fail the whole operation for avatar upload failure
        }
    }

    func deleteSubject() async {
        guard let subject = editingSubject else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await dataManager?.deleteSubject(
                subjectId: subject.subjectId,
                deviceId: deviceID
            )

            // Refresh devices
            if let userId = userAccountManager?.currentUser?.id {
                await deviceManager?.initializeDevices(for: userId)
            }

            // Notify deletion
            NotificationCenter.default.post(name: NSNotification.Name("SubjectUpdated"), object: nil)

            isLoading = false
            showingSuccessAlert = true

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}