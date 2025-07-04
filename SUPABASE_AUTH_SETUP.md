# WatchMe iOS - Supabase認証統合セットアップガイド

## 概要

WatchMe iOSアプリにSupabase認証機能を統合し、ログインユーザーのIDで音声ファイルをアップロードできるようになりました。

## 🔧 実装した機能

### 1. Supabase認証システム
- **SupabaseAuthManager.swift**: Supabase auth.usersテーブルとの認証統合
- **サインアップ/ログイン**: メール・パスワード認証
- **状態永続化**: UserDefaultsによる認証状態保存
- **自動再ログイン**: アプリ再起動時の認証状態復元

### 2. ログイン画面
- **LoginView.swift**: SwiftUIによるログイン/サインアップUI
- **レスポンシブデザイン**: エラーメッセージ表示対応
- **モード切り替え**: ログイン⇄サインアップの切り替え機能

### 3. 認証統合
- **MainAppView**: ログイン状態に応じた画面切り替え
- **ContentView更新**: ログインユーザー情報表示・ログアウト機能
- **NetworkManager統合**: 認証ユーザーIDでの音声アップロード

## 📱 ユーザーフロー

### 未ログイン時
1. **起動画面**: WatchMeロゴとログインボタン表示
2. **ログインボタンタップ**: ログイン画面をモーダル表示
3. **認証完了**: メイン機能画面に自動遷移

### ログイン済み時
1. **メイン画面**: 録音・アップロード機能を完全利用可能
2. **ユーザー情報表示**: ログインメールアドレス・ユーザーID表示
3. **ログアウト**: 確認ダイアログ付きログアウト機能

## 🔐 認証仕様

### Supabase設定
```swift
private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### 認証エンドポイント
- **ログイン**: `POST /auth/v1/token?grant_type=password`
- **サインアップ**: `POST /auth/v1/signup`

### データモデル
```swift
struct SupabaseUser: Codable {
    let id: String           // auth.users.id (UUID)
    let email: String        // ユーザーメールアドレス
    let accessToken: String  // アクセストークン
    let refreshToken: String? // リフレッシュトークン
}
```

## 🎤 音声アップロード統合

### ユーザーID使用
- **認証済み**: `auth.users.id` (UUID形式)を使用
- **フォールバック**: 従来の `user_xxxxxxxx` 形式を維持

### アップロード先
- **URL**: `https://api.hey-watch.me/upload` (変更なし)
- **パラメーター**: `user_id` = 認証ユーザーID

### 実装例
```swift
// 認証済みユーザーIDを使用
if let authenticatedUser = authManager.currentUser {
    networkManager.updateToAuthenticatedUserID(authenticatedUser.id)
}

// アップロード時
body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
body.append("\(currentUserID)\r\n") // 認証ユーザーIDが送信される
```

## 📂 新規追加ファイル

### 1. SupabaseAuthManager.swift
**場所**: `/ios_watchme_v9/SupabaseAuthManager.swift`

**機能**:
- Supabase認証API呼び出し
- ユーザー状態管理 (`@Published` プロパティ)
- UserDefaults永続化
- エラーハンドリング

**主要メソッド**:
- `signIn(email:password:)`: ログイン処理
- `signUp(email:password:)`: サインアップ処理
- `signOut()`: ログアウト・状態クリア
- `checkAuthStatus()`: 保存状態復元

### 2. LoginView.swift
**場所**: `/ios_watchme_v9/LoginView.swift`

**機能**:
- SwiftUIログイン画面
- メール・パスワード入力フィールド
- ログイン/サインアップモード切り替え
- エラーメッセージ表示
- ローディング状態表示

**デザイン特徴**:
- WatchMeブランディング統一
- アクセシビリティ対応
- レスポンシブレイアウト

## 🔄 既存ファイル更新

### 1. ios_watchme_v9App.swift
**変更内容**:
- `SupabaseAuthManager` StateObject追加
- `MainAppView` による認証状態ルーティング
- EnvironmentObject として認証管理を注入

### 2. ContentView.swift
**変更内容**:
- `@EnvironmentObject var authManager` 追加
- ユーザー情報表示エリア更新
- ログアウト確認ダイアログ追加
- NetworkManager初期化時に認証ユーザーID設定

### 3. NetworkManager.swift
**変更内容**:
- `init(authManager:)` 認証管理統合
- `updateToAuthenticatedUserID()` メソッド追加
- `resetToFallbackUserID()` メソッド追加
- 認証ユーザーID優先ロジック

## 🚀 セットアップ手順

### 1. プロジェクトファイル追加
Xcodeで以下のファイルを手動追加:
```
ios_watchme_v9/
├── SupabaseAuthManager.swift
└── LoginView.swift
```

### 2. ビルドターゲット設定
1. **Xcode起動**: `ios_watchme_v9.xcodeproj` 開く
2. **ファイル追加**: Project Navigator で右クリック → "Add Files"
3. **ターゲット選択**: `ios_watchme_v9` ターゲットにチェック

### 3. コンパイル確認
```bash
xcodebuild -project ios_watchme_v9.xcodeproj \
           -scheme ios_watchme_v9 \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

### 4. 実行テスト
1. **シミュレータ起動**: iPhone 16 シミュレータ
2. **アプリ実行**: Xcode → Product → Run
3. **ログイン機能テスト**: サインアップ→ログイン→録音→アップロード

## 🧪 テストシナリオ

### 認証フロー
1. **未ログイン状態でアプリ起動**: ログイン画面表示確認
2. **新規サインアップ**: メール・パスワードで新規アカウント作成
3. **ログイン**: 作成したアカウントでログイン
4. **状態永続化**: アプリ再起動後も認証状態維持確認
5. **ログアウト**: ログアウト後に再度ログイン画面表示

### 音声アップロード
1. **ログイン後録音開始**: 正常に録音開始できること
2. **ユーザーID確認**: ログインユーザーIDが表示されること
3. **音声アップロード**: 録音ファイルが認証ユーザーIDで送信されること
4. **サーバーログ確認**: `https://api.hey-watch.me` で認証ユーザーID受信確認

### UI/UX
1. **レスポンシブデザイン**: 各種iPhone サイズで正常表示
2. **エラーハンドリング**: 無効なメール・パスワードでエラー表示
3. **ローディング状態**: 認証中のスピナー表示
4. **状態遷移**: スムーズな画面切り替え

## 📊 データフロー図

```
[アプリ起動]
    ↓
[SupabaseAuthManager.checkAuthStatus()]
    ↓
[保存された認証状態?] → No → [ログイン画面表示]
    ↓ Yes                        ↓
[MainAppView.ContentView]      [LoginView]
    ↓                          [認証成功] → [状態保存]
[認証ユーザーID取得]                    ↓
    ↓                          [MainAppView.ContentView]
[NetworkManager.updateToAuthenticatedUserID()]
    ↓
[録音・アップロード機能]
    ↓
[user_id = 認証UUID で送信]
    ↓
[https://api.hey-watch.me/upload]
```

## ⚠️ 注意事項

### 1. セキュリティ
- **パスワード**: アプリ内では暗号化された状態で通信
- **トークン**: UserDefaultsに保存 (Keychainより簡易だが十分)
- **通信**: HTTPS通信で保護

### 2. エラーハンドリング
- **ネットワークエラー**: 適切なユーザーメッセージ表示
- **認証エラー**: 詳細なエラー理由表示
- **フォールバック**: 認証失敗時は従来ユーザーID使用

### 3. 互換性
- **既存機能**: 従来の録音・アップロード機能は完全保持
- **ユーザーID**: 認証ユーザーID使用時も従来形式と互換
- **アップロード先**: `https://api.hey-watch.me` は変更なし

## 🔮 今後の拡張

### 1. プロファイル管理
- **ユーザー名編集**: メールアドレス変更機能
- **アカウント設定**: プロファイル画像アップロード
- **統計情報**: アップロード履歴・統計表示

### 2. セキュリティ強化
- **Keychain統合**: トークンをより安全に保存
- **生体認証**: Touch ID・Face ID ログイン
- **セッション管理**: トークン自動更新

### 3. Supabase統合拡張
- **リアルタイム**: Supabase Realtime でアップロード状態同期
- **ストレージ**: Supabase Storage で音声ファイル保存
- **データベース**: public.users テーブル連携

## 📞 サポート

### 開発者情報
- **作成者**: Kaya Matsumoto
- **実装日**: 2025年7月4日
- **バージョン**: v9.1 (Supabase認証統合版)

### ドキュメント
- **Supabase認証**: https://supabase.com/docs/guides/auth
- **iOS SwiftUI**: https://developer.apple.com/documentation/swiftui
- **WatchMe要件**: 既存README.md参照

---

このセットアップガイドに従って、WatchMe iOSアプリでSupabase認証を使用した音声アップロード機能を利用できます。