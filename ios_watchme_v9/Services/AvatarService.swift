//
//  AvatarService.swift
//  ios_watchme_v9
//
//  Unified avatar upload service
//  Handles complete avatar upload flow: S3 upload + DB save + cache clear
//

import UIKit
import Foundation

/// Avatar service for unified avatar management
class AvatarService {

    static let shared = AvatarService()

    private init() {}

    // MARK: - Public Methods

    /// Upload avatar for user
    /// - Parameters:
    ///   - image: Avatar image
    ///   - userId: User ID
    ///   - authToken: Authentication token
    ///   - dataManager: Supabase data manager
    /// - Returns: Uploaded avatar URL
    @discardableResult
    func uploadUserAvatar(
        image: UIImage,
        userId: String,
        authToken: String?,
        dataManager: SupabaseDataManager
    ) async throws -> URL {
        print("👤 [AvatarService] Starting user avatar upload: \(userId)")

        // 1. Upload to S3
        let avatarUrl = try await AWSManager.shared.uploadAvatar(
            image: image,
            type: "users",
            id: userId,
            authToken: authToken
        )
        print("✅ [AvatarService] S3 upload successful: \(avatarUrl)")

        // 2. Save to database
        try await dataManager.updateUserAvatarUrl(
            userId: userId,
            avatarUrl: avatarUrl.absoluteString
        )
        print("✅ [AvatarService] Database updated: \(avatarUrl.absoluteString)")

        // 3. Clear ALL caches (ImageCache + URLCache)
        await MainActor.run {
            ImageCacheManager.shared.removeImage(for: avatarUrl)
            URLCache.shared.removeCachedResponse(for: URLRequest(url: avatarUrl))
        }
        print("✅ [AvatarService] All caches cleared (ImageCache + URLCache)")

        return avatarUrl
    }

    /// Upload avatar for subject
    /// - Parameters:
    ///   - image: Avatar image
    ///   - subjectId: Subject ID
    ///   - authToken: Authentication token
    ///   - dataManager: Supabase data manager
    /// - Returns: Uploaded avatar URL
    @discardableResult
    func uploadSubjectAvatar(
        image: UIImage,
        subjectId: String,
        authToken: String?,
        dataManager: SupabaseDataManager
    ) async throws -> URL {
        print("👤 [AvatarService] Starting subject avatar upload: \(subjectId)")

        // 1. Upload to S3
        let avatarUrl = try await AWSManager.shared.uploadAvatar(
            image: image,
            type: "subjects",
            id: subjectId,
            authToken: authToken
        )
        print("✅ [AvatarService] S3 upload successful: \(avatarUrl)")

        // 2. Save to database
        try await dataManager.updateSubjectAvatarUrl(
            subjectId: subjectId,
            avatarUrl: avatarUrl.absoluteString
        )
        print("✅ [AvatarService] Database updated: \(avatarUrl.absoluteString)")

        // 3. Clear ALL caches (ImageCache + URLCache)
        await MainActor.run {
            ImageCacheManager.shared.removeImage(for: avatarUrl)
            URLCache.shared.removeCachedResponse(for: URLRequest(url: avatarUrl))
        }
        print("✅ [AvatarService] All caches cleared (ImageCache + URLCache)")

        return avatarUrl
    }
}
