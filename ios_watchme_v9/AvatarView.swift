//
//  AvatarView.swift
//  ios_watchme_v9
//
//  Optimized avatar view with centralized image caching
//

import SwiftUI

// Avatar type enum
enum AvatarType {
    case user
    case subject

    var s3Type: String {
        switch self {
        case .user:
            return "users"
        case .subject:
            return "subjects"
        }
    }
}

struct AvatarView: View {
    let type: AvatarType
    let id: String?
    let size: CGFloat
    let providedAvatarUrl: String? // SSOT: Subject.avatarUrl or User.avatarUrl from parent

    // Compatibility initializer (for existing user usage)
    init(userId: String?, size: CGFloat = 80, avatarUrl: String? = nil) {
        self.type = .user
        self.id = userId
        self.size = size
        self.providedAvatarUrl = avatarUrl
    }

    // General initializer
    init(type: AvatarType, id: String?, size: CGFloat = 80, avatarUrl: String? = nil) {
        self.type = type
        self.id = id
        self.size = size
        self.providedAvatarUrl = avatarUrl
    }

    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var displayImage: UIImage?
    @State private var isLoadingAvatar = false

    var body: some View {
        Group {
            if let image = displayImage {
                // Display cached/downloaded avatar image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.safeColor("BorderLight").opacity(0.2), lineWidth: 1)
                    )
            } else {
                // Default avatar icon (loading state or no avatar)
                defaultAvatarView
                    .overlay(
                        Group {
                            if isLoadingAvatar {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    )
            }
        }
        .task(id: providedAvatarUrl) {
            // Load avatar when providedAvatarUrl changes
            await loadAvatar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AvatarUpdated"))) { _ in
            // Reload avatar when update notification is received
            Task {
                await loadAvatar()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SubjectUpdated"))) { _ in
            // Reload avatar when Subject is updated (from DeviceManager)
            Task {
                await loadAvatar()
            }
        }
    }

    private func loadAvatar() async {
        // Return early if no avatar URL is provided
        guard let providedUrl = providedAvatarUrl, !providedUrl.isEmpty else {
            await MainActor.run {
                self.displayImage = nil
                self.isLoadingAvatar = false
            }
            return
        }

        // Add cache-busting timestamp to force refresh if needed
        let timestamp = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "\(providedUrl)?t=\(timestamp)") else {
            await MainActor.run {
                self.displayImage = nil
                self.isLoadingAvatar = false
            }
            return
        }

        await MainActor.run {
            self.isLoadingAvatar = true
        }

        // Get image from cache manager (will download if not cached)
        let image = await ImageCacheManager.shared.getImage(for: url)

        await MainActor.run {
            self.displayImage = image
            self.isLoadingAvatar = false
        }
    }

    private var defaultAvatarView: some View {
        ZStack {
            // White background
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)

            // Gray icon
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .foregroundColor(.gray)
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.safeColor("BorderLight").opacity(0.2), lineWidth: 1)
        )
    }
}