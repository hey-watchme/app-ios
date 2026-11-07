//
//  AvatarService.swift
//  ios_watchme_v9
//
//  Uploads avatars straight to Supabase Storage (bucket "avatars") and saves
//  the public URL on the user or subject row. Images arrive already cropped
//  (Mantis), so this only resizes and encodes them.
//

import UIKit
import Foundation
import Supabase

class AvatarService {
    static let shared = AvatarService()

    private let bucket = "avatars"
    private let maxDimension: CGFloat = 512
    private let jpegQuality: CGFloat = 0.85

    private init() {}

    @discardableResult
    func uploadUserAvatar(
        image: UIImage,
        userId: String,
        authToken: String?,
        dataManager: SupabaseDataManager
    ) async throws -> URL {
        let avatarUrl = try await upload(image: image, path: "users/\(userId.lowercased())/avatar.jpg")
        try await dataManager.updateUserAvatarUrl(userId: userId, avatarUrl: avatarUrl.absoluteString)
        return avatarUrl
    }

    @discardableResult
    func uploadSubjectAvatar(
        image: UIImage,
        subjectId: String,
        authToken: String?,
        dataManager: SupabaseDataManager
    ) async throws -> URL {
        let avatarUrl = try await upload(image: image, path: "subjects/\(subjectId.lowercased())/avatar.jpg")
        try await dataManager.updateSubjectAvatarUrl(subjectId: subjectId, avatarUrl: avatarUrl.absoluteString)
        return avatarUrl
    }

    /// Uploads (overwriting) and returns a versioned public URL, so every
    /// cache keyed by URL picks up the new image immediately.
    private func upload(image: UIImage, path: String) async throws -> URL {
        guard let data = resized(image).jpegData(compressionQuality: jpegQuality) else {
            throw AvatarServiceError.imageEncodingFailed
        }

        let storage = supabase.storage.from(bucket)
        try await storage.upload(
            path,
            data: data,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        )

        let publicURL = try storage.getPublicURL(path: path)
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        guard let versionedURL = components?.url else {
            throw AvatarServiceError.invalidURL
        }
        return versionedURL
    }

    private func resized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

enum AvatarServiceError: LocalizedError {
    case imageEncodingFailed
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "画像の変換に失敗しました"
        case .invalidURL:
            return "画像のURLを作れませんでした"
        }
    }
}
