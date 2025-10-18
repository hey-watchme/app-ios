# アカウント削除機能の実装仕様

このドキュメントは、WatchMeアプリのアカウント削除機能の実装に関する仕様と要件を定義します。

---

## 📋 概要

App Storeのガイドラインに準拠するため、ユーザーが自分のアカウントとデータを完全に削除できる機能を実装する必要があります。

### 法的要件
- **App Store Review Guidelines 5.1.1**: ユーザーがアカウント削除を要求できる機能の提供
- **GDPR（EU一般データ保護規則）**: データ削除権（Right to Erasure）
- **日本の個人情報保護法**: 個人情報の消去請求

---

## 🎯 削除の範囲

### 1. **削除すべきデータ**

#### ✅ 必須削除項目
- [ ] **ユーザーアカウント情報**
  - `auth.users` テーブルのレコード（Supabase Auth）
  - `public.users` テーブルのレコード
  - メールアドレス、パスワードハッシュ

- [ ] **音声データ**
  - S3バケットに保存された全音声ファイル
  - ファイル命名規則: `recordings/{user_id}/{device_id}/{date}/{time}.wav`

- [ ] **画像データ**
  - S3バケットに保存されたアバター画像
  - ファイル命名規則: `avatars/users/{user_id}/avatar.jpg`

- [ ] **分析データ**
  - `dashboard_summary` テーブルのレコード
  - `emotion_reports` テーブルのレコード（存在する場合）
  - `behavior_reports` テーブルのレコード（存在する場合）

- [ ] **デバイス情報**
  - `devices` テーブルのレコード
  - APNsデバイストークン

- [ ] **コメント・投稿データ**
  - `subject_comments` テーブルのレコード
  - その他のユーザー生成コンテンツ

#### ⚠️ 削除を検討すべき項目
- [ ] **通知履歴**
  - `notifications` テーブルのレコード（個人を特定できる情報が含まれる場合）

- [ ] **ログデータ**
  - アクセスログ（個人を特定できる情報は削除）
  - エラーログ（個人情報は匿名化）

#### 🔒 削除しない（匿名化する）項目
- [ ] **統計データ**
  - 個人を特定できない形式で集計された統計データ
  - 匿名化された分析結果（研究・改善目的）

---

## 🛠️ 実装方針

### Phase 1: iOS アプリ側の実装

#### 1. UI実装
- ✅ `AccountSettingsView.swift` に「アカウントを削除」ボタンを追加（完了）
- [ ] 削除確認ダイアログの改善（2段階確認）
- [ ] 削除理由のフィードバック収集（任意）

#### 2. 削除フロー
```swift
// 推奨フロー
1. ユーザーが「アカウントを削除」をタップ
2. 警告ダイアログ表示（1回目）
   - 「削除すると復元できません」
3. 確認ダイアログ表示（2回目）
   - テキスト入力で「削除」と入力させる（誤操作防止）
4. バックエンドAPIに削除リクエスト送信
5. 削除完了後、ログアウト処理
6. ログイン画面に遷移
```

#### 3. API呼び出し
```swift
// NetworkManager.swift に追加
func deleteAccount(userId: String) async throws {
    let url = URL(string: "\(baseURL)/user/delete")!
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["user_id": userId]
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.deleteFailed
    }
}
```

---

### Phase 2: バックエンド側の実装

#### 1. API エンドポイント作成
- [ ] `DELETE /user/delete` エンドポイントの作成
- [ ] 認証トークンの検証
- [ ] ユーザーID確認（削除対象が本人か確認）

#### 2. データベーステーブルの削除順序

**重要**: 外部キー制約により、以下の順序で削除する必要があります。

```python
# 推奨削除順序（依存関係の順）
1. subject_comments (コメント)
2. notifications (通知)
3. dashboard_summary (ダッシュボード)
4. emotion_reports (感情分析)
5. behavior_reports (行動分析)
6. devices (デバイス)
7. public.users (ユーザープロファイル)
8. auth.users (認証情報) ← Supabase Admin APIを使用
```

**注意**: `ON DELETE CASCADE` が設定されているテーブルは自動削除されるため、明示的な削除不要。

#### 3. S3ファイルの削除

```python
import boto3

def delete_user_s3_files(user_id: str):
    s3_client = boto3.client('s3')
    bucket_name = 'your-bucket-name'

    # 音声ファイルの削除
    recordings_prefix = f'recordings/{user_id}/'
    response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=recordings_prefix)

    if 'Contents' in response:
        objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]
        s3_client.delete_objects(
            Bucket=bucket_name,
            Delete={'Objects': objects_to_delete}
        )

    # アバター画像の削除
    avatar_key = f'avatars/users/{user_id}/avatar.jpg'
    s3_client.delete_object(Bucket=bucket_name, Key=avatar_key)
```

#### 4. Supabase Auth の削除

```python
from supabase import create_client, Client

def delete_supabase_auth_user(user_id: str):
    # Service Roleキーを使用（管理者権限）
    supabase: Client = create_client(
        supabase_url="https://your-project.supabase.co",
        supabase_key="your-service-role-key"
    )

    # auth.usersからユーザーを削除
    supabase.auth.admin.delete_user(user_id)
```

---

### Phase 3: データ削除の検証

#### 削除確認チェックリスト
- [ ] データベースから全レコードが削除されたか確認
- [ ] S3バケットから全ファイルが削除されたか確認
- [ ] Supabase Authからユーザーが削除されたか確認
- [ ] 削除後にログインできないことを確認
- [ ] 削除後にデータが復元できないことを確認

---

## 🔐 セキュリティ要件

### 1. 認証・認可
- [ ] 削除リクエストは認証済みユーザーのみ実行可能
- [ ] 削除対象のユーザーIDと認証トークンのユーザーIDが一致することを確認
- [ ] セッションタイムアウト後は削除不可

### 2. ログ記録
- [ ] 削除実行のログを記録（監査証跡）
  - ユーザーID
  - 削除実行日時
  - 削除理由（任意）
  - 削除成功/失敗ステータス

### 3. エラーハンドリング
- [ ] 削除中にエラーが発生した場合のロールバック処理
- [ ] 部分的に削除が失敗した場合のリトライ機能
- [ ] ユーザーへのエラー通知

---

## 📧 削除後の通知

### ユーザーへの確認メール
削除完了後、登録されているメールアドレスに確認メールを送信：

```
件名: アカウント削除のお知らせ

お客様のWatchMeアカウントが削除されました。

削除日時: 2025-10-18 14:30 JST
削除されたデータ:
- ユーザーアカウント情報
- 音声録音データ
- 分析結果
- デバイス情報

ご利用ありがとうございました。

※このメールに心当たりがない場合は、privacy@watchme.app までご連絡ください。
```

---

## 🕐 削除タイミングと猶予期間

### オプション1: 即時削除（厳格）
- ユーザーが削除を実行すると即座に削除
- 復元不可能

### オプション2: 猶予期間付き削除（推奨）
- 削除リクエスト後、30日間の猶予期間
- 猶予期間中はアカウント無効化（ログイン不可）
- 期間中にキャンセル可能
- 30日後に自動的に完全削除

**推奨**: オプション2（ユーザーフレンドリー）

---

## 📊 削除統計の記録（匿名化）

削除されたアカウントの統計情報を匿名化して記録：

```sql
CREATE TABLE account_deletions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    deleted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    account_age_days INTEGER, -- アカウント作成から削除までの日数
    deletion_reason TEXT, -- 削除理由（任意）
    total_recordings INTEGER, -- 削除された録音ファイル数
    user_id_hash TEXT -- ハッシュ化されたユーザーID（復元不可能）
);
```

**注意**: 個人を特定できる情報は一切保存しない

---

## 🚀 実装優先度

### 🔴 Phase 1: 完全削除（App Store審査必須）
1. ✅ iOS アプリUIの実装（完了）
2. [ ] **データベースインデックスの確認・作成**

   **確認済み（✅ 既存）**:
   - `users(user_id)` - UNIQUE INDEX
   - `notifications(user_id)`
   - `user_devices(user_id)`
   - `subjects(created_by_user_id)`
   - `subject_comments(user_id)`
   - `notification_reads(user_id)`

   **✅ 追加インデックス不要**:
   ```sql
   -- dashboard_summary テーブルのスキーマ確認結果：
   -- ❌ user_id カラムは存在しない
   -- ❌ subject_id カラムも存在しない
   -- ✅ PRIMARY KEY (device_id, date) が存在

   -- 削除方法：
   -- 1. user_devices テーブルから device_id を取得
   -- 2. device_id で dashboard_summary を削除（既存の PRIMARY KEY で高速）
   ```

   **注意**: `dashboard_summary` には `user_id` が直接存在しないため、`user_devices` テーブル経由でデバイスIDを取得してから削除します。既存のPRIMARY KEYで十分高速なため、追加のインデックスは不要です。
3. [ ] バックエンドAPI `/user/delete` エンドポイント作成
4. [ ] データベースレコードの削除実装
5. [ ] **S3ファイルの完全削除実装**
   - 音声データ（wav/mp3ファイル）
   - アバター画像
   - その他すべてのユーザー関連ファイル
6. [ ] Supabase Auth削除実装

**方針**: Phase 1では**すべてのデータを完全削除**（最も安全な方法）

### 🟡 中優先度（UX向上）
7. [ ] 削除確認メールの送信
8. [ ] 削除理由のフィードバック収集
9. [ ] 2段階確認ダイアログの実装

### 🟢 Phase 2: 機械学習フィードバックループ（将来対応）
10. [ ] 猶予期間付き削除の実装
11. [ ] 削除統計の記録
12. [ ] **機械学習用データ保持の法的整備**（下記「Phase 2の詳細」参照）

---

## 🔬 Phase 2: 機械学習フィードバックループの設計（将来対応）

### 目的
ユーザーのデータを活用してサービス精度を向上させるためのフィードバックループを構築する。

### 課題認識
- ❌ 音声データそのもの → 個人情報（削除必須）
- ❌ 発話内容（テキスト） → 個人情報（削除必須）
- ❓ 音響的特徴（パラメーター） → ラベルなしでは無意味
- ✅ ラベル付き音響特徴 → 機械学習に有用（ただし法的整備が必要）

### 検討すべき保持データ

#### オプションA: 音響特徴量のみ（匿名化）
```python
# 保持するデータ例
{
    "feature_id": "uuid",  # ランダムID（user_id削除）
    "acoustic_features": [
        {"mfcc": [0.1, 0.2, ...], "pitch": 120, "energy": 0.8},
        # 音響的特徴のみ
    ],
    "emotion_label": "happy",  # AIが推論した感情ラベル
    "timestamp": "2025-10",  # 月単位（日時は曖昧化）
}
```

**問題点**: ユーザーIDがないため、同一人物の時系列データとして扱えない → 学習効果が限定的

#### オプションB: 仮名化ID付き音響特徴（推奨検討案）
```python
{
    "anonymous_user_id": "hash(user_id + salt)",  # 元に戻せない仮名化ID
    "acoustic_features": [...],
    "emotion_label": "happy",
    "behavioral_context": "conversation",  # 行動コンテキスト
    "timestamp": "2025-10",
}
```

**メリット**:
- 同一ユーザーの時系列データとして学習可能
- 元のuser_idには戻せない（仮名化）
- 音声データ自体は削除済み

**法的要件**:
- 明確な同意取得が必要
- プライバシーポリシーへの明記
- データ利用目的の透明性

### 必要な法的対応

#### 1. 同意取得フロー

**サインアップ時**:
```
☑ サービス改善のための匿名化データ利用に同意します（任意）

【詳細】
アカウント削除後も、以下の条件で匿名化されたデータを保持します：
・音響的特徴量のみ保持（音声ファイル・発話内容は削除）
・個人を特定できる情報は完全削除
・サービス改善・機械学習モデルの向上のみに使用
・第三者への提供は一切行いません

※この同意はいつでも撤回でき、撤回後はすべてのデータを削除します
```

#### 2. プライバシーポリシーへの追記

```markdown
### 機械学習用データの保持（任意）

ユーザーの同意がある場合、アカウント削除後も以下のデータを匿名化して保持することがあります：

【保持するデータ】
- 音響的特徴量（MFCC、ピッチ、エネルギー等のパラメーター）
- 感情・行動の分析結果ラベル
- 匿名化されたユーザーID（元に戻すことはできません）

【保持しないデータ】
- 音声ファイルそのもの
- 発話内容（テキスト）
- メールアドレス、氏名等の個人情報

【利用目的】
サービスの精度向上および機械学習モデルの改善

【同意の撤回】
アプリ設定画面から、いつでも同意を撤回し、すべてのデータを削除できます。
```

### 実装イメージ

#### データベース設計
```sql
-- 匿名化された学習用データ
CREATE TABLE ml_training_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anonymous_user_id TEXT NOT NULL,  -- hash(user_id + salt)
    acoustic_features JSONB NOT NULL,
    emotion_label TEXT,
    behavioral_label TEXT,
    created_month DATE NOT NULL,  -- 月単位（日時は保存しない）
    consent_given_at TIMESTAMP WITH TIME ZONE NOT NULL,
    INDEX idx_anonymous_user_id (anonymous_user_id)
);

-- ユーザーの同意状態管理
CREATE TABLE ml_consent (
    user_id UUID PRIMARY KEY REFERENCES public.users(user_id) ON DELETE CASCADE,
    consent_given BOOLEAN DEFAULT FALSE,
    consent_date TIMESTAMP WITH TIME ZONE,
    revoked_date TIMESTAMP WITH TIME ZONE
);
```

#### 削除時の処理（完全版）
```python
@app.delete("/user/delete")
async def delete_user_account(user_id: str):
    # 1. ユーザーの全デバイスIDを取得
    devices = supabase.table('user_devices') \
        .select('device_id') \
        .eq('user_id', user_id) \
        .execute()

    device_ids = [d['device_id'] for d in devices.data]

    # 2. dashboard_summary を削除（デバイスごと）
    for device_id in device_ids:
        supabase.table('dashboard_summary') \
            .delete() \
            .eq('device_id', device_id) \
            .execute()

    # 3. subject_comments を削除
    supabase.table('subject_comments') \
        .delete() \
        .eq('user_id', user_id) \
        .execute()

    # 4. notifications を削除
    supabase.table('notifications') \
        .delete() \
        .eq('user_id', user_id) \
        .execute()

    # 5. subjects を削除
    supabase.table('subjects') \
        .delete() \
        .eq('created_by_user_id', user_id) \
        .execute()

    # 6. user_devices を削除
    supabase.table('user_devices') \
        .delete() \
        .eq('user_id', user_id) \
        .execute()

    # 7. S3ファイル削除
    delete_s3_files(user_id)

    # 8. public.users を削除
    supabase.table('users') \
        .delete() \
        .eq('user_id', user_id) \
        .execute()

    # 9. auth.users を削除（Service Role必要）
    supabase.auth.admin.delete_user(user_id)

    return {"message": "アカウントを削除しました"}

def delete_s3_files(user_id: str):
    """S3からユーザーのファイルを削除"""
    s3_client = boto3.client('s3')
    bucket = 'your-bucket-name'

    # 音声ファイル削除
    recordings_prefix = f'recordings/{user_id}/'
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=recordings_prefix)
    if 'Contents' in response:
        objects = [{'Key': obj['Key']} for obj in response['Contents']]
        s3_client.delete_objects(Bucket=bucket, Delete={'Objects': objects})

    # アバター画像削除
    avatar_key = f'avatars/users/{user_id}/avatar.jpg'
    s3_client.delete_object(Bucket=bucket, Key=avatar_key)
```

### Phase 2実装の前提条件
- [ ] 法務専門家によるレビュー
- [ ] プライバシーポリシーの更新
- [ ] 同意取得フローの実装
- [ ] データ匿名化処理の実装
- [ ] 同意撤回機能の実装

---

## 📝 関連ドキュメント

- [プライバシーポリシー](https://hey-watch.me/privacy) - データ保存期間の記載
- [App Store Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [GDPR Article 17 - Right to Erasure](https://gdpr-info.eu/art-17-gdpr/)

---

## 🔄 次のステップ

### Phase 1（App Storeリリース前）
1. ✅ データベースインデックスの確認・作成
2. バックエンドAPI実装の着手
3. データベース削除スクリプトの作成
4. S3削除機能の実装（完全削除）
5. テスト環境での削除フロー検証
6. 本番環境へのデプロイ

### Phase 2（サービス成熟後）
1. 法務専門家による機械学習データ保持のレビュー
2. プライバシーポリシーの更新
3. 同意取得フローの設計・実装
4. 音響特徴量抽出・匿名化処理の実装
5. フィードバックループの構築

---

**最終更新日**: 2025-10-18
**担当者**: 開発チーム
**ステータス**: Phase 1仕様策定完了 / Phase 2検討中
**リリース方針**: Phase 1（完全削除）で審査申請 → Phase 2は将来実装
