# 認証システム詳細ドキュメント

最終更新: 2025-11-26

> **関連ドキュメント**
> - [README.md](../../README.md) - アプリ全体の概要
> - [TECHNICAL.md](../technical/TECHNICAL.md) - アーキテクチャ・データベース設計
> - [CHANGELOG.md](../../CHANGELOG.md) - 更新履歴

---

## 📋 開発状況

### ✅ 実装済み
- 匿名認証（Anonymous Authentication）
- Google OAuth認証（ASWebAuthenticationSession使用）
- `public.users`テーブルに`auth_provider`カラム追加
- 認証プロバイダーの区別（anonymous, email, google, apple, microsoft等）
- **匿名ユーザーのアップグレードフロー**（ゲスト → Googleアカウント連携）
  - email/auth_providerの自動更新機能
  - 既存データ（アバター等）の完全引き継ぎ
- **認証状態管理の簡素化**（UserAuthState: unauthenticated/authenticated）
- **ユーザーステータス表示**（マイページにステータスラベル表示）
- **エラーメッセージ表示の統一**（ToastManager活用）
- **fullScreenCover二重ネスト問題の解消**（AuthFlowView統合）
- **タブビュー構造の重複解消**（MainAppViewリファクタリング）

### 🚧 現在の課題
- **Google OAuth認証**: 実機テストで最終確認が必要
  - シミュレータでは正常動作を確認
  - モーダルクローズ問題は解消済み（fullScreenCover統合による）
  - **次回セッション**: 実機での認証フロー確認

### 📚 データベース参照先
- **スキーマ管理**: `/Users/kaya.matsumoto/projects/watchme/server-configs/database/`
- **最新マイグレーション**: `migrations/20251125000000_add_auth_provider_to_users.sql`
- **スキーマドキュメント**: `current_schema.sql` (最終更新: 2025-11-25)

---

## 🔐 認証フロー

### 初回起動時のフロー

```
アプリ起動
  ↓
初期画面（ロゴ + 「はじめる」「ログイン」）
  ↓「はじめる」押下
統合認証フロー（AuthFlowView）
  ├─ オンボーディング（4ページのスライド）
  └─ アカウント選択画面
      ┃
      ┣━ 🔵 Google でサインイン（実装済み）
      ┣━ 📧 メールアドレスで登録（準備中）
      ┗━ 👤 ゲストとして続行（匿名認証・実装済み）
```

### 匿名ユーザーのアップグレードフロー

```
ゲストモードでログイン
  ↓
アカウント設定画面を開く
  ↓
「アカウントを作成してデータを保護」セクションが表示
  ↓
タップしてUpgradeAccountViewを表示
  ┃
  ┣━ 🔵 Google でアカウント作成
  ┗━ 📧 メールアドレスで登録（準備中）
  ↓
既存データを保持したままアカウントアップグレード完了
```

---

## 🔑 認証方式

### 1. 匿名認証（Anonymous Authentication）

**対象**: 初めて使うユーザー、すぐに試したいユーザー

**特徴**:
- アカウント登録不要で即座に全機能を利用可能
- Supabaseの匿名認証機能を使用
- **後でメールアドレスやGoogle認証にアップグレード可能**（UI実装済み）

**制限事項**:
- アプリ削除またはデータクリアでアカウント喪失
- 複数デバイスでの同期不可

**実装状況**: ✅ 完全動作（アップグレードフロー含む）

**`auth_provider`値**: `"anonymous"`

**関連ファイル**:
- `UserAccountManager.swift:293-339` - `isAnonymousUser`, `userStatusLabel`
- `UserAccountManager.swift:1403-1477` - `upgradeAnonymousToGoogle()`
- `UserAccountManager.swift:599-669` - `createOrUpdateUserProfile()` (email/auth_provider更新処理)
- `UpgradeAccountView.swift` - アカウント登録UI
- `AccountSettingsView.swift:29-58` - アカウント登録ボタン
- `UserInfoView.swift:85-89` - ユーザーステータス表示

---

### 2. Google OAuth認証

**対象**: Googleアカウントを持つユーザー

**特徴**:
- ワンタップで簡単ログイン
- パスワード管理不要
- 複数デバイスでの同期可能

**技術実装**:
- iOS標準の`ASWebAuthenticationSession`を使用
- Supabase OAuth (Implicit Flow: `#access_token=...`)
- Google Cloud Console OAuth 2.0クライアント設定済み

**URL Scheme**: `watchme://auth/callback`

**フロー**:
```
アプリ → ASWebAuthenticationSession（Googleログイン）→ アプリに自動復帰
```

**実装状況**: ✅ 実装完了（シミュレータで動作確認済み）
- **fullScreenCover二重ネスト問題を解消**（AuthFlowViewで統合）
- **モーダル自動クローズ機能を改善**

**`auth_provider`値**: `"google"`

**実装ファイル**:
- `UserAccountManager.swift:1354-1401` - `signInWithGoogleDirect()`
- `UserAccountManager.swift:1403-1477` - `upgradeAnonymousToGoogle()`
- `UserAccountManager.swift:512-596` - `handleOAuthCallback()`
- `AuthFlowView.swift` - 統合認証フロー（オンボーディング + アカウント選択）

---

### 3. メールアドレス/パスワード認証（準備中）

**対象**: メールアドレスで登録したいユーザー

**特徴**:
- 従来型の認証方式
- 複数デバイスでの同期可能

**実装状況**: 🚧 モックアップのみ（`signUp()`メソッドは実装済み）

**`auth_provider`値**: `"email"`

---

## 👥 ユーザーアカウントの種類

| 種類 | email | auth_provider | 複数デバイス | データ保護 | 実装状況 |
|------|-------|--------------|------------|----------|---------|
| 匿名ユーザー | `"anonymous"` | `"anonymous"` | ❌ | ⚠️ 脆弱 | ✅ 実装済み |
| Googleユーザー | Googleアカウント | `"google"` | ✅ | ✅ 安全 | ✅ 実装済み |
| メールユーザー | 登録メール | `"email"` | ✅ | ✅ 安全 | 🚧 準備中 |
| Appleユーザー | Appleアカウント | `"apple"` | ✅ | ✅ 安全 | 📋 未実装 |

**`auth_provider`フィールド**:
- `public.users`テーブルで認証プロバイダーを区別
- CHECK制約で許可される値: `anonymous`, `email`, `google`, `apple`, `microsoft`, `github`, `facebook`, `twitter`
- 将来的な拡張性を考慮した設計

---

## 🔐 認証状態

### UserAuthState（簡素化版）

アプリの認証状態は2つのみ：

| 状態 | 説明 | 権限 |
|------|------|------|
| `.unauthenticated` | 未認証（起動直後、ログアウト後） | なし（AuthFlowViewが表示される） |
| `.authenticated(userId)` | 認証済み（匿名含む） | 全機能利用可能 |

**重要**: ユーザーは必ず認証フロー（Google/メール/匿名）を経由するため、`.unauthenticated`状態は一時的なもの。

### ユーザーステータス表示

マイページには`userStatusLabel`プロパティで以下のステータスを表示：

- **ゲストユーザー**: `auth_provider = "anonymous"`
- **Googleアカウント連携**: `auth_provider = "google"`
- **メールアドレス連携**: `auth_provider = "email"`
- **Appleアカウント連携**: `auth_provider = "apple"`

---

## 🗄️ データベース設計

### ユーザー認証テーブル

**重要原則**: `auth.users`への直接参照は禁止。必ず`public.users(user_id)`を使用。

**テーブル構造**:
- **`auth.users`**: Supabase認証専用テーブル（直接アクセス不可）
- **`public.users`**: アプリケーション用ユーザープロファイル（✅ 推奨）
  - `user_id` (UUID, PRIMARY KEY): `auth.users.id`と対応
  - `email` (TEXT): ユーザーのメールアドレス（匿名の場合は`"anonymous"`）
  - `auth_provider` (TEXT, NOT NULL): 認証プロバイダー
  - `apns_token` (TEXT): プッシュ通知用トークン
  - その他フィールド: `name`, `avatar_url`, `status`, `subscription_plan`等

**コード例**:

```swift
// ❌ 間違い
let userId = userAccountManager.currentUser?.id

// ✅ 正しい
let userId = userAccountManager.currentUser?.profile?.userId
```

---

## 👤 ユーザーとデバイスの関係

- **1ユーザー = 複数の観測対象デバイス + 1台の通知先デバイス**
- 観測対象デバイス: 録音される人を表す論理的なID
- 通知先デバイス: プッシュ通知を受信するユーザーのiPhone

---

## 💻 実装詳細

### 匿名ユーザーの判定

```swift
var isAnonymousUser: Bool {
    return currentUser?.email == "anonymous"
}
```

### 主要ファイル

| ファイル | 説明 |
|---------|------|
| `UserAccountManager.swift` | 認証ロジック（Google、匿名、アップグレード） |
| `AuthFlowView.swift` | 統合認証フロー（オンボーディング + アカウント選択） |
| `UpgradeAccountView.swift` | アカウントアップグレードUI（ゲスト → Google） |
| `AccountSettingsView.swift` | 設定画面（アップグレードバナー表示） |
| `LoginView.swift` | ログイン画面（メール/パスワード） |
| `SignUpView.swift` | 会員登録画面（メール/パスワード） |
| `OnboardingView.swift` | オンボーディング画面（※AuthFlowViewで統合済み） |
| `AccountSelectionView.swift` | アカウント選択画面（※AuthFlowViewで統合済み） |

---

## 🔧 開発時の注意点

### fullScreenCoverのネスト禁止

モーダルが自動的に閉じない問題を防ぐため、fullScreenCoverは1層のみに制限してください。

**解決済みの事例**:
- AuthFlowViewでオンボーディングとアカウント選択を統合
- iOS 18以降ではfullScreenCover内でさらにfullScreenCoverを表示すると、親が自動的に閉じない問題が発生

### エラー表示の統一

すべての認証エラーは`ToastManager`で表示してください。

```swift
// ✅ 正しい
toastManager.showError(title: "認証エラー", subtitle: errorMessage)

// ❌ 間違い
.alert("エラー", isPresented: $showAlert) { ... }
```

### OAuth URL Schemeの設定

`Info.plist` に以下のURL Schemeが設定されています：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>watchme</string>
        </array>
    </dict>
</array>
```

---

## 🧪 テスト項目

認証機能の修正後は以下をテストしてください：

### 匿名認証
- [ ] 「ゲストとして続行」でログインできること
- [ ] 全機能が利用できること
- [ ] アカウント設定に「アカウントを作成してデータを保護」バナーが表示されること

### Google OAuth認証
- [ ] 「Google でサインイン」でログインできること
- [ ] Google認証画面が表示され、認証後に自動的にアプリに戻ること
- [ ] 認証後にモーダルが自動的に閉じること
- [ ] ホーム画面が表示されること

### アップグレードフロー
- [ ] ゲストユーザーでログイン
- [ ] 設定画面から「アカウントを作成してデータを保護」をタップ
- [ ] Google認証が成功すること
- [ ] 既存データが保持されていること（デバイス、録音データ等）
- [ ] auth_providerが`anonymous` → `google`に更新されること

### 認証状態の遷移
- [ ] ログイン → ログアウトの状態遷移で問題がないこと
- [ ] 全権限モード ↔ 閲覧専用モードの切り替えが正常に動作すること
- [ ] タブ切り替えが全モードで正常に動作すること

---

## 🐛 既知の問題と解決策

### 問題1: fullScreenCover二重ネスト（✅ 解決済み）

**問題**: OnboardingView内でfullScreenCoverを使用し、モーダルクローズが不安定

**解決**: AuthFlowViewで統合し、1層のfullScreenCoverのみに変更

**コミット**: `d978be5 Fix fullScreenCover nesting issue by unifying authentication flow`

---

### 問題2: エラーメッセージの表示が不統一（✅ 解決済み）

**問題**: 各所でバラバラなエラー表示（Alert、独自UI等）

**解決**: ToastManagerで全エラーを統一的に表示

**コミット**: `3509361 Unify error message display using ToastManager`

---

### 問題3: タブビュー構造の重複（✅ 解決済み）

**問題**: MainAppViewで認証済み・未認証の2箇所に同じタブビュー構造が重複

**解決**: `private var mainTabView`で共通化

**コミット**: `c8afe2c Refactor MainAppView to eliminate duplicate tab view structure`

---

## 📱 画面とファイルの対応表

| 通称 | 正式名称 | ファイル名 | 説明 |
|------|---------|-----------|------|
| **初期画面** | ウェルカム画面 | `ios_watchme_v9App.swift`（内部のMainAppView） | ロゴと「はじめる」「ログイン」ボタン |
| **統合認証フロー** | オンボーディング + アカウント選択 | `AuthFlowView.swift` | オンボーディング（4ページ）とアカウント選択を1つのフローに統合 |
| **アップグレード画面** | アカウントアップグレード | `UpgradeAccountView.swift` | ゲストユーザーがGoogleアカウントに移行する画面 |
| **ログイン画面** | ログイン | `LoginView.swift` | メールアドレスとパスワードでログイン |
| **会員登録画面** | 会員登録 | `SignUpView.swift` | メールアドレスとパスワードで新規登録 |

**非推奨（後方互換性のため残存）**:
- `OnboardingView.swift` - AuthFlowViewで統合済み
- `AccountSelectionView.swift` - AuthFlowViewで統合済み

---

## 📚 技術スタック

- **Supabase** - 認証（匿名認証・Google OAuth）・データベース・ストレージ
- **ASWebAuthenticationSession** - iOS標準のOAuth認証UI
- **Google Cloud Platform** - OAuth 2.0クライアント（Google認証）
- **Combine** - リアクティブプログラミング

---

## 🔗 参考リンク

### データベーススキーマ
- スキーマ管理: `/Users/kaya.matsumoto/projects/watchme/server-configs/database/`
- 最新スキーマ: `current_schema.sql`
- マイグレーション: `migrations/20251125000000_add_auth_provider_to_users.sql`

### 外部サービス
- [Supabase Dashboard](https://supabase.com/dashboard)
- [Google Cloud Console](https://console.cloud.google.com/)
