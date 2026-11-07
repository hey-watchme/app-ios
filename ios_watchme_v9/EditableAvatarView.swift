//
//  EditableAvatarView.swift
//  ios_watchme_v9
//
//  The one avatar editor used everywhere (user profile, subject profile,
//  subject registration): tap the avatar -> camera / library -> crop -> save.
//  After saving it refreshes the source data, so every screen that shows the
//  same avatar updates too.
//

import SwiftUI

struct EditableAvatarView: View {
    let type: AvatarType
    let entityId: String?
    let avatarUrl: String?
    var size: CGFloat = 100
    var isEditable: Bool = true
    var ringColor: Color = Color(.systemBackground)
    var onUploaded: ((URL) -> Void)? = nil

    @EnvironmentObject private var userAccountManager: UserAccountManager
    @EnvironmentObject private var deviceManager: DeviceManager
    @EnvironmentObject private var dataManager: SupabaseDataManager

    @StateObject private var viewModel: AvatarUploadViewModel
    @State private var showingPicker = false
    @State private var uploadedUrl: String?

    init(
        type: AvatarType,
        entityId: String?,
        avatarUrl: String?,
        size: CGFloat = 100,
        isEditable: Bool = true,
        ringColor: Color = Color(.systemBackground),
        onUploaded: ((URL) -> Void)? = nil
    ) {
        self.type = type
        self.entityId = entityId
        self.avatarUrl = avatarUrl
        self.size = size
        self.isEditable = isEditable
        self.ringColor = ringColor
        self.onUploaded = onUploaded
        _viewModel = StateObject(wrappedValue: AvatarUploadViewModel(avatarType: type, entityId: entityId))
    }

    private var displayedUrl: String? { uploadedUrl ?? avatarUrl }
    private var canEdit: Bool { isEditable && !(entityId ?? "").isEmpty }
    private var badgeSize: CGFloat { max(20, size * 0.32) }

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(type: type, id: entityId, size: size, avatarUrl: displayedUrl)
                    .overlay(Circle().stroke(ringColor, lineWidth: size >= 80 ? 4 : 2))

                if canEdit {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: badgeSize, height: badgeSize)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: badgeSize * 0.5))
                                .foregroundColor(.black)
                        )
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
        .accessibilityLabel(canEdit ? "写真を変更" : "写真")
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                AvatarPickerView(
                    viewModel: viewModel,
                    currentAvatarURL: displayedUrl.flatMap { $0.isEmpty ? nil : URL(string: $0) }
                )
                .navigationTitle("写真を選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showingPicker = false
                            viewModel.reset()
                        }
                    }
                }
            }
            .preferredColorScheme(.light)
        }
        .onAppear(perform: configure)
        .onChange(of: entityId) { configure() }
    }

    private func configure() {
        viewModel.entityId = entityId
        viewModel.authToken = userAccountManager.getAccessToken()
        viewModel.dataManager = dataManager
        viewModel.onSuccess = { url in
            Task { @MainActor in
                uploadedUrl = url.absoluteString
                showingPicker = false
                onUploaded?(url)
                await refreshSource()
            }
        }
    }

    /// Reload whatever the other screens read the avatar from.
    private func refreshSource() async {
        guard let userId = userAccountManager.effectiveUserId else { return }
        switch type {
        case .user:
            await userAccountManager.fetchUserProfile(userId: userId)
        case .subject:
            await deviceManager.loadDevices(for: userId)
        }
    }
}
