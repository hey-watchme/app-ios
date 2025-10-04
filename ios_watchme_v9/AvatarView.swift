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
    let useS3: Bool = true // ✅ Avatar Uploader APIを使用してS3に保存
    
    // 互換性のための初期化（既存のuser用）
    init(userId: String?, size: CGFloat = 80) {
        self.type = .user
        self.id = userId
        self.size = size
    }
    
    // 汎用的な初期化
    init(type: AvatarType, id: String?, size: CGFloat = 80) {
        self.type = type
        self.id = id
        self.size = size
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AvatarUpdated"))) { _ in
            // アバターが更新されたら再読み込み
            lastUpdateTime = Date()
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        Task {
            guard let id = id else {
                print("⚠️ IDが指定されていません（type: \(type)）")
                isLoadingAvatar = false
                return
            }
            
            isLoadingAvatar = true
            
            if useS3 {
                // S3のURLを設定（Avatar Uploader API経由でアップロード済み）
                let baseURL = AWSManager.shared.getAvatarURL(type: type.s3Type, id: id)
                let timestamp = Int(lastUpdateTime.timeIntervalSince1970)
                self.avatarUrl = URL(string: "\(baseURL.absoluteString)?t=\(timestamp)")
                print("🌐 Loading \(type.s3Type) avatar from S3: \(self.avatarUrl?.absoluteString ?? "nil")")
            } else {
                // Supabaseから取得（既存の実装、userのみ対応）
                if type == .user {
                    self.avatarUrl = await dataManager.fetchAvatarUrl(for: id)
                } else {
                    // subjectの場合はS3のみ対応
                    print("⚠️ Subject avatars are only supported via S3")
                    self.avatarUrl = nil
                }
            }
            
            self.isLoadingAvatar = false
        }
    }
    
    private var defaultAvatarView: some View {
        ZStack {
            // 白い背景の円
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)

            // デフォルトアイコン
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size))
                .foregroundColor(Color.safeColor("PrimaryActionColor"))
        }
        .overlay(
            Circle()
                .stroke(Color.safeColor("BorderLight").opacity(0.2), lineWidth: 1)
        )
    }
}