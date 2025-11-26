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

## 🗑️ アカウント削除

### 📋 概要

App Storeのガイドラインに準拠するため、ユーザーが自分のアカウントとデータを完全に削除できる機能を実装しています。

**法的要件**:
- **App Store Review Guidelines 5.1.1**: ユーザーがアカウント削除を要求できる機能の提供
- **GDPR（EU一般データ保護規則）**: データ削除権（Right to Erasure）
- **日本の個人情報保護法**: 個人情報の消去請求

---

### 🎯 削除の範囲

#### ✅ 必須削除項目

**ユーザーアカウント情報**:
- `auth.users` テーブルのレコード（Supabase Auth）
- `public.users` テーブルのレコード
- メールアドレス、パスワードハッシュ、`auth_provider`

**音声データ**:
- S3バケット内の全音声ファイル
- ファイル命名規則: `recordings/{user_id}/{device_id}/{date}/{time}.wav`
- ✅ **自動削除**: Janitor APIが6時間ごとに自動削除（分析完了後24時間以内）

**画像データ**:
- S3バケット内のアバター画像
- ファイル命名規則: `avatars/users/{user_id}/avatar.jpg`

**分析データ**:
- `dashboard_summary` テーブル（device_id経由）
- その他の分析結果テーブル

**デバイス連携情報**:
- `user_devices` テーブル（ユーザーとデバイスの紐付け）
- APNsデバイストークン
- ✅ **孤立デバイスの自動削除**: 削除ユーザーが唯一の参照者の場合、`devices`テーブルからも自動削除（Cascading Delete）

**コメント・投稿データ**:
- `subject_comments` テーブル
- `subjects` テーブル（created_by_user_id）

**通知データ**:
- `notifications` テーブル
- `notification_reads` テーブル

#### 🔒 削除しない（匿名化する）項目

**統計データ**:
- 個人を特定できない形式で集計された統計データ
- 匿名化された分析結果（将来的な研究・改善目的）

---

### 🔄 認証プロバイダー別の削除フロー

#### 1. 匿名ユーザー（`auth_provider = "anonymous"`）

**特徴**:
- アプリ削除でアカウント自動喪失
- 削除確認は必須（誤操作防止）

**削除フロー**:
```
設定画面 → 「アカウントを削除」
  ↓
警告ダイアログ（1回目）
  ↓
確認ダイアログ（2回目）
  ↓
管理画面APIに削除リクエスト（DELETE /api/users/{user_id}）
  ↓
Supabase Auth削除（auth.users）+ public.users削除
  ↓
ログアウト → AuthFlowView表示
```

#### 2. Googleユーザー（`auth_provider = "google"`）

**特徴**:
- 複数デバイスで同期しているため、影響範囲が大きい
- 削除後、同じGoogleアカウントで再登録可能

**削除フロー**:
```
設定画面 → 「アカウントを削除」
  ↓
警告ダイアログ（複数デバイスの注意喚起）
  ↓
確認ダイアログ（テキスト入力で「削除」と入力）
  ↓
管理画面APIに削除リクエスト
  ↓
全デバイスのデータ削除 + Supabase Auth削除
  ↓
ログアウト → AuthFlowView表示
```

#### 3. メールユーザー（`auth_provider = "email"`）

**実装状況**: 🚧 準備中

**削除フロー**:
- Googleユーザーと同様の処理
- 削除確認メールの送信（任意）

---

### 🔧 デバイス削除機能

**実装状況**: ✅ 実装完了（2025-11-26）

#### デバイス削除とアカウント削除の違い

| 項目 | アカウント削除 | デバイス削除 |
|------|-------------|------------|
| **対象** | ユーザーアカウント全体 | 特定のデバイス本体 |
| **削除されるもの** | `user_devices`（連携）のみ | `devices`テーブル（デバイス本体） + 全ユーザーとの連携 |
| **デバイス本体** | 削除されない | 削除される |
| **実行場所** | マイページ > アカウント設定 | デバイス詳細画面 |

#### デバイス削除の実装

**UI**:
- **場所**: デバイス詳細画面（DeviceEditView）
- **ボタン配置**: 「デバイス連携解除」の下に「このデバイスを削除」
- **確認ダイアログ**: 2段階確認（誤操作防止）

**削除フロー**:
```
デバイス詳細画面 → 「このデバイスを削除」
  ↓
確認ダイアログ
  ↓
管理画面APIに削除リクエスト（DELETE /api/devices/{device_id}）
  ↓
devices テーブルから削除
  ↓
画面を閉じる → デバイスリスト再読み込み
```

**実装ファイル**:
- `DeviceEditView.swift:135-158` - 「このデバイスを削除」ボタン
- `DeviceEditView.swift:213-222` - 削除確認ダイアログ
- `DeviceEditView.swift:296-324` - `deleteDevice()` メソッド
- `NetworkManager.swift:690-723` - `deleteDevice(deviceId:)` メソッド
- 管理画面API: `DELETE /api/devices/{device_id}` (main.py:319-329)

#### 将来的な拡張（Phase 2）

デバイス削除時に以下も削除できるようにする：
- `dashboard_summary` テーブル（デバイスの分析結果）
- `subjects` テーブル（デバイスに紐付いた観測対象情報）
- `subject_comments` テーブル（観測対象へのコメント）

---

### 🛠️ 実装状況

#### ✅ Phase 1-A（実装完了 - 2025-11-26）

**管理画面API経由での削除機能**:
- エンドポイント: `DELETE https://admin.hey-watch.me/api/users/{user_id}`
- 削除対象:
  - `user_devices` テーブル（ユーザーとデバイスの紐付け）
  - `devices` テーブル（**孤立デバイスのみ自動削除** - Cascading Delete）
  - `auth.users` テーブル（Supabase Admin API使用）
  - `public.users` テーブル（ON DELETE CASCADE）

**孤立デバイス削除ロジック**（2025-11-26追加）:
- 削除ユーザーが所有するデバイスを確認
- 他のユーザーが参照していないデバイスを検出
- 孤立デバイスを自動削除（データベースのクリーン化）
- 実装場所: `/Users/kaya.matsumoto/projects/watchme/admin/main.py:252-312`

**iOSアプリ統合**:
- `NetworkManager.swift:655-689` - `deleteAccount(userId:)` メソッド
- `AccountSettingsView.swift:196-229` - 削除フロー実装
- パフォーマンス最適化: NetworkManagerを遅延初期化（削除時のみインスタンス化）
- ✅ 実機テスト成功
- ✅ ビルド検証成功

**音声データ自動削除**:
- Janitor APIにより6時間ごとに自動削除
- アカウント削除時の手動削除は**不要**

#### 🚧 Phase 1-B（残タスク）

**管理画面APIの拡張**:
1. [ ] **通知データの削除**
   - `notifications` テーブルから該当ユーザーの通知を削除
   - 実装場所: `/Users/kaya.matsumoto/projects/watchme/admin/main.py`

2. [ ] **S3アバター画像の削除**
   - `avatars/users/{user_id}/avatar.jpg` を削除
   - boto3を使用（requirements.txtに追加済み）
   - 実装場所: `/Users/kaya.matsumoto/projects/watchme/admin/main.py`

3. [ ] **関連データの削除**
   - `dashboard_summary` テーブル（device_id経由）
   - `subject_comments` テーブル
   - `subjects` テーブル（created_by_user_id）

4. [ ] **本番環境への反映**
   - GitHub ActionsでCI/CD自動デプロイ（既存システム）
   - mainブランチにプッシュすると自動デプロイされる

**実装例**:
```python
# /Users/kaya.matsumoto/projects/watchme/admin/main.py

@app.delete("/api/users/{user_id}")
async def delete_user(user_id: str):
    try:
        # 1. デバイスID取得
        devices = await supabase_client.select('user_devices', filters={'user_id': user_id})
        device_ids = [d['device_id'] for d in devices]

        # 2. dashboard_summary削除（デバイスごと）
        for device_id in device_ids:
            await supabase_client.delete('dashboard_summary', {'device_id': device_id})

        # 3. subject_comments削除
        await supabase_client.delete('subject_comments', {'user_id': user_id})

        # 4. notifications削除
        await supabase_client.delete('notifications', {'user_id': user_id})

        # 5. subjects削除
        await supabase_client.delete('subjects', {'created_by_user_id': user_id})

        # 6. S3アバター画像削除
        delete_avatar_image(user_id)

        # 7. user_devices削除（既存）
        await supabase_client.delete('user_devices', {'user_id': user_id})

        # 8. auth.users削除（既存）
        await supabase_client.delete_auth_user(user_id)

        return {"success": True, "message": "完全削除しました"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def delete_avatar_image(user_id: str):
    """S3からアバター画像を削除"""
    import boto3
    import os

    s3_client = boto3.client('s3')
    bucket = os.getenv('S3_BUCKET_NAME')  # 環境変数に追加必要
    avatar_key = f'avatars/users/{user_id}/avatar.jpg'

    try:
        s3_client.delete_object(Bucket=bucket, Key=avatar_key)
        print(f"✅ S3アバター削除: {avatar_key}")
    except Exception as e:
        print(f"⚠️ S3アバター削除エラー（存在しない可能性）: {e}")
```

#### 🟢 Phase 2（将来対応）

**機械学習フィードバックループ**:
1. [ ] 法務専門家による機械学習データ保持のレビュー
2. [ ] プライバシーポリシーの更新
3. [ ] 同意取得フローの設計・実装
4. [ ] 音響特徴量抽出・匿名化処理の実装
5. [ ] フィードバックループの構築

**検討事項**:
- 音声データそのもの → 削除必須
- 発話内容（テキスト） → 削除必須
- 音響的特徴（パラメーター） → ラベルなしでは無意味
- ラベル付き音響特徴 → 機械学習に有用（法的整備が必要）

---

### 🔐 セキュリティ要件

**認証・認可**:
- [ ] 削除リクエストは認証済みユーザーのみ実行可能
- [ ] 削除対象のユーザーIDと認証トークンのユーザーIDが一致することを確認
- [ ] セッションタイムアウト後は削除不可

**ログ記録**:
- [ ] 削除実行のログを記録（監査証跡）
  - ユーザーID
  - 削除実行日時
  - 削除理由（任意）
  - 削除成功/失敗ステータス

**エラーハンドリング**:
- [ ] 削除中にエラーが発生した場合のロールバック処理
- [ ] 部分的に削除が失敗した場合のリトライ機能
- [ ] ユーザーへのエラー通知

---

### 🕐 削除タイミングと猶予期間

#### オプション1: 即時削除（現在の実装）
- ユーザーが削除を実行すると即座に削除
- 復元不可能

#### オプション2: 猶予期間付き削除（将来検討）
- 削除リクエスト後、30日間の猶予期間
- 猶予期間中はアカウント無効化（ログイン不可）
- 期間中にキャンセル可能
- 30日後に自動的に完全削除

**推奨**: オプション2（ユーザーフレンドリー）

---

### 📧 削除後の通知

**ユーザーへの確認メール**（将来実装）:
```
件名: アカウント削除のお知らせ

お客様のWatchMeアカウントが削除されました。

削除日時: 2025-11-26 14:30 JST
削除されたデータ:
- ユーザーアカウント情報
- 音声録音データ
- 分析結果
- デバイス情報

ご利用ありがとうございました。

※このメールに心当たりがない場合は、privacy@watchme.app までご連絡ください。
```

---

### 📊 削除統計の記録（匿名化）

**将来実装予定**:
```sql
CREATE TABLE account_deletions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    deleted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    account_age_days INTEGER, -- アカウント作成から削除までの日数
    deletion_reason TEXT, -- 削除理由（任意）
    total_recordings INTEGER, -- 削除された録音ファイル数
    auth_provider TEXT, -- 削除時の認証プロバイダー
    user_id_hash TEXT -- ハッシュ化されたユーザーID（復元不可能）
);
```

**注意**: 個人を特定できる情報は一切保存しない

---

### 🚀 実装優先度

**🔴 Phase 1: 完全削除（App Store審査必須）**:
1. ✅ iOS アプリUIの実装（完了）
2. ✅ 基本的な削除API実装（完了）
3. [ ] データベースレコードの完全削除実装
4. [ ] S3ファイルの完全削除実装
5. [ ] 削除確認メールの送信

**🟡 中優先度（UX向上）**:
6. [ ] 削除理由のフィードバック収集
7. [ ] 2段階確認ダイアログの実装
8. [ ] 猶予期間付き削除の実装

**🟢 Phase 2: 機械学習フィードバックループ（将来対応）**:
9. [ ] 機械学習用データ保持の法的整備
10. [ ] 削除統計の記録

---

### 🧪 削除機能のテスト項目

**匿名ユーザーの削除**:
- [ ] 削除確認ダイアログが表示されること
- [ ] 削除後、全データが削除されていること
- [ ] 削除後、ログアウトされること
- [ ] 削除後、AuthFlowViewが表示されること
- [ ] 削除後、同じデバイスで再度匿名ログインできること

**Googleユーザーの削除**:
- [ ] 削除確認ダイアログが表示されること（複数デバイスの警告付き）
- [ ] 削除後、全データが削除されていること
- [ ] 削除後、S3のアバター画像が削除されていること
- [ ] 削除後、通知データが削除されていること
- [ ] 削除後、ログアウトされること
- [ ] 削除後、同じGoogleアカウントで再登録できること

**削除の検証**:
- [ ] データベースから全レコードが削除されたか確認
- [ ] S3バケットから全ファイルが削除されたか確認
- [ ] Supabase Authからユーザーが削除されたか確認
- [ ] 削除後にログインできないことを確認（同じ匿名アカウントでは不可）
- [ ] 削除後にデータが復元できないことを確認

---

### 📝 関連ドキュメント

- [プライバシーポリシー](https://hey-watch.me/privacy) - データ保存期間の記載
- [App Store Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [GDPR Article 17 - Right to Erasure](https://gdpr-info.eu/art-17-gdpr/)

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
