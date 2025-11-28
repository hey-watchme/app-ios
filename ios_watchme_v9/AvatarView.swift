//
//  AvatarView.swift
//  ios_watchme_v9
//

import SwiftUI

// アバタータイプの列挙型
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
    let useS3: Bool = true // ✅ Avatar Uploader APIを使用してS3に保存

    // 互換性のための初期化（既存のuser用）
    init(userId: String?, size: CGFloat = 80, avatarUrl: String? = nil) {
        self.type = .user
        self.id = userId
        self.size = size
        self.providedAvatarUrl = avatarUrl
    }

    // 汎用的な初期化
    init(type: AvatarType, id: String?, size: CGFloat = 80, avatarUrl: String? = nil) {
        self.type = type
        self.id = id
        self.size = size
        self.providedAvatarUrl = avatarUrl
    }

    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var avatarUrl: URL?
    @State private var isLoadingAvatar = true
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        Group {
            if isLoadingAvatar {
                // 読み込み中はデフォルトアイコンをプレースホルダーとして表示
                defaultAvatarView
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
                                    .stroke(Color.safeColor("BorderLight").opacity(0.2), lineWidth: 1)
                            )
                    case .failure(_):
                        // エラー時のデフォルトアイコン
                        defaultAvatarView
                    case .empty:
                        // 読み込み中もデフォルトアイコンを表示
                        defaultAvatarView
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
        .onChange(of: id) { oldValue, newValue in
            loadAvatar()
        }
        .onChange(of: providedAvatarUrl) { oldValue, newValue in
            // SSOT が更新されたら即座に再読み込み
            print("🔄 [AvatarView] providedAvatarUrl changed: \(oldValue ?? "nil") -> \(newValue ?? "nil")")
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
            guard let id = id else {
                isLoadingAvatar = false
                return
            }

            isLoadingAvatar = true

            // SSOT: providedAvatarUrl を優先使用
            if let providedUrl = providedAvatarUrl, !providedUrl.isEmpty {
                // Parent component から渡された avatar_url を使用（Subject.avatarUrl など）
                let timestamp = Int(lastUpdateTime.timeIntervalSince1970)
                self.avatarUrl = URL(string: "\(providedUrl)?t=\(timestamp)")
                print("✅ [AvatarView] Using provided avatarUrl from SSOT: \(providedUrl)")
            } else if useS3 {
                // Fallback: S3のURLを設定（Avatar Uploader API経由でアップロード済み）
                let baseURL = AWSManager.shared.getAvatarURL(type: type.s3Type, id: id)
                let timestamp = Int(lastUpdateTime.timeIntervalSince1970)
                self.avatarUrl = URL(string: "\(baseURL.absoluteString)?t=\(timestamp)")
                print("⚠️ [AvatarView] Using S3 fallback URL (providedAvatarUrl was nil)")
            } else {
                // Supabaseから取得（既存の実装、userのみ対応）
                if type == .user {
                    self.avatarUrl = await dataManager.fetchAvatarUrl(for: id)
                } else {
                    // subjectの場合はS3のみ対応
                    self.avatarUrl = nil
                }
            }

            self.isLoadingAvatar = false
        }
    }
    
    private var defaultAvatarView: some View {
        ZStack {
            // 白い背景
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)

            // グレーのアイコン
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