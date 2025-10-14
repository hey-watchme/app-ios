# WatchMe プッシュ通知アーキテクチャ（AWS SNS + APNs）

**作成日**: 2025-10-13
**最終更新**: 2025-10-15
**ステータス**: ✅ 実装完了・動作確認済み

---

## 📖 用語定義（重要）

本ドキュメントでは、以下の用語を明確に区別します：

| 用語 | 説明 | データベース | 例 |
|------|------|------------|------|
| **観測対象デバイス** または **録音デバイス** | 音声データを収集するデバイス | `devices`テーブル | 松本遍のApple Watch、松本正弦のApple Watch |
| **通知先デバイス** または **iPhoneデバイス** | プッシュ通知を受信するユーザーのiPhone | - | ユーザーのiPhone（1ユーザーにつき1台） |
| **APNsトークン** | 通知先デバイス（iPhone）を一意に識別するトークン | `users.apns_token` | 7cb89fa1198f12001efa... |
| **device_id** | 観測対象デバイスのUUID | `devices.device_id` | d067d407-cf73-4174-a9c1-d91fb60d64d0 |
| **user_id** | ユーザーのUUID | `users.user_id` | 164cba5a-dba6-4cbc-9b39-4eea28d98fa5 |

**重要**：1人のユーザーは、**複数の観測対象デバイス**（録音デバイス）を所有できますが、**通知先デバイス（iPhone）は1台のみ**です。

---

## 📊 概要

Lambda処理完了後、iOSアプリにリアルタイムでデータ更新を通知するため、AWS SNS + Apple Push Notification service (APNs)を使用します。

### 🎯 目的

- Lambda処理完了後、即座にiOSアプリ（通知先デバイス）に通知
- ユーザーがアプリを開いているときは自動的にデータ再取得
- スケーラブルで信頼性の高い通知システム

---

## 🏗️ アーキテクチャ

```mermaid
graph LR
    subgraph "観測対象デバイス（録音デバイス）"
        A1[松本遍のApple Watch]
        A2[松本正弦のApple Watch]
    end

    subgraph "Lambda処理"
        A1 --> B[dashboard-analysis-worker]
        A2 --> B
        B --> C[dashboard_summary更新]
    end

    subgraph "プッシュ通知"
        C --> D[SNS Platform Endpoint]
        D --> E[APNs]
    end

    subgraph "通知先デバイス（iPhone）"
        E --> F[プッシュ通知受信]
        F --> G{アプリ状態}
        G -->|Foreground| H[トーストバナー表示]
        G -->|Background| I[サイレント通知]
        H --> J[今日のキャッシュクリア]
        I --> J
        J --> K[データ再取得]
    end
```

**データフロー**：
1. **観測対象デバイス**（録音デバイス）から音声データ送信
2. Lambda処理完了後、該当ユーザーの**通知先デバイス**（iPhone）にプッシュ通知送信
3. **1ユーザーにつき1つのAPNsトークン**（複数の観測対象デバイスがあっても、通知先は1台のiPhoneのみ）

---

## ✅ 実装済み内容（2025-10-14）

### 1. AWS SNS Platform Application

#### 開発環境（Sandbox）
- **名前**: `watchme-ios-app-sandbox`
- **ARN**: `arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-sandbox`
- **証明書**: Sandbox用APNs証明書（有効期限: 確認要）
- **用途**: Xcodeから直接インストールしたアプリ

#### 本番環境（Production）
- **名前**: `watchme-ios-app`
- **ARN**: `arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app`
- **証明書**: Production用APNs証明書（有効期限: 2026-11-12）
- **用途**: TestFlight/App Store公開版

---

### 2. Lambda関数実装

**ファイル**: `/Users/kaya.matsumoto/projects/watchme/server-configs/lambda-functions/watchme-dashboard-analysis-worker/lambda_function.py`

#### 主要機能

1. **プッシュ通知送信** (`send_push_notification`)
   - SupabaseからAPNsトークンを取得
   - SNS Platform Endpointを自動作成または更新
   - プッシュ通知を送信

2. **Endpoint自動再有効化**
   - `EndpointDisabledException`を自動検知
   - Endpointを再有効化してリトライ

3. **現在の設定**
   - **環境**: Sandbox（開発用）
   - **通知タイプ**: 通常の通知（バナー表示）※テスト用
   - **ペイロード**: `APNS_SANDBOX`

```python
SNS_PLATFORM_APP_ARN = 'arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-sandbox'

message = {
    'APNS_SANDBOX': json.dumps({
        'aps': {
            'alert': {
                'title': 'データ更新完了',
                'body': '新しい分析結果が利用可能です'
            },
            'sound': 'default',
            'content-available': 1
        },
        'device_id': device_id,
        'date': date,
        'action': 'refresh_dashboard'
    })
}
```

---

### 3. IAM権限設定

**ロール**: `watchme-dashboard-analysis-worker-role-ff2gu1tt`

**ポリシー**: `SNSPushNotificationPolicy`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish",
        "sns:CreatePlatformEndpoint",
        "sns:SetEndpointAttributes",
        "sns:GetEndpointAttributes"
      ],
      "Resource": [
        "arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app",
        "arn:aws:sns:ap-southeast-2:754724220380:endpoint/APNS/watchme-ios-app/*",
        "arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-sandbox",
        "arn:aws:sns:ap-southeast-2:754724220380:endpoint/APNS_SANDBOX/watchme-ios-app-sandbox/*"
      ]
    }
  ]
}
```

---

### 4. iOS側実装

#### デバイストークン管理
- ✅ APNsデバイストークン取得機能実装済み
- ✅ トークンをSupabase `users.apns_token`に保存（2025-10-14修正）
- ✅ ログイン後に自動的にトークン登録・保存
- ✅ テストデバイストークン: `7cb89fa1198f12001efa7ab7aa45cbfc3f04b7b15d113911f9058cbd348a2652`

#### プッシュ通知ハンドラー
- ✅ `AppDelegate`実装済み
- ✅ フォアグラウンド受信処理
- ✅ バックグラウンド受信処理
- ✅ 通知タップ時の処理
- ✅ トーストバナー表示実装済み（フォアグラウンド時）

---

## 🐛 解決した問題

### 問題1: UNUserNotificationCenterDelegateが設定されていない（2025-10-14）
**エラー**: プッシュ通知が届かない（Xcodeコンソールに何も出力されない）

**原因**: `UNUserNotificationCenter.current().delegate = self`が設定されていなかった

**解決**:
`ios_watchme_v9App.swift`の`AppDelegate.didFinishLaunchingWithOptions`に追加：
```swift
UNUserNotificationCenter.current().delegate = self
```

---

### 問題2: TabView内で通知が重複受信される（2025-10-14）
**現象**: 1回の通知で7回のキャッシュクリア・データ再取得が実行される

**原因**: TabViewが複数のSimpleDashboardViewインスタンスを事前生成し、全てが`onReceive`で同じ通知を受信していた

**解決**:
`SimpleDashboardView.swift`の`onReceive`処理を修正：
- このビューの`date`が今日でない場合は早期リターン
- 不要なログ出力を削減

```swift
// このビューが今日を表示中の場合のみ処理
guard calendar.isDate(date, inSameDayAs: today) else {
    return
}
```

---

### 問題3: Lambda関数で`requests`ライブラリがない
**エラー**: `Runtime.ImportModuleError: No module named 'requests'`

**原因**: 依存ライブラリがデプロイパッケージに含まれていなかった

**解決**:
```bash
cd /Users/kaya.matsumoto/projects/watchme/server-configs/lambda-functions/watchme-dashboard-analysis-worker
./build.sh
aws lambda update-function-code --function-name watchme-dashboard-analysis-worker --zip-file fileb://function.zip --region ap-southeast-2
```

---

### 問題4: APNs環境のミスマッチ
**エラー**: `EndpointDisabled`

**原因**:
- SNS Platform Application = **Production環境（APNS）**
- iOSアプリ（Xcodeビルド） = **Sandbox環境**
- 環境が一致していなかった

**解決**:
1. Sandbox用APNs証明書を作成（`.p12`）
2. SNS Platform Application `watchme-ios-app-sandbox`を作成
3. Lambda関数を`APNS_SANDBOX`に変更

---

### 問題5: IAM権限不足
**エラー**: `AuthorizationError: User is not authorized to perform: SNS:CreatePlatformEndpoint on resource: arn:aws:sns:.../APNS_SANDBOX/...`

**原因**: IAMポリシーが本番環境のARNのみ許可していた

**解決**: IAMポリシーにSandbox環境のARNを追加

---

### 問題6: APNsトークンの保存先が間違っている（2025-10-14）
**エラー**: トークンが取得できない、または間違った観測対象デバイスでプッシュ通知が動作しない

**原因**:
- APNsトークンを`devices`テーブル（観測対象デバイス）に保存していた（設計ミス）
- `user_devices.role='owner'`で絞り込んでいたため、一部観測対象デバイスで通知が届かない

**解決**:
1. **データベース設計変更**
   - APNsトークンの保存先を`devices`（観測対象デバイス）→`users`（ユーザー）テーブルに変更
   - `users.apns_token`カラムを追加
   - `devices.apns_token`カラムを削除

2. **iOS側修正**
   - `DeviceManager.swift`: トークン保存処理を`users`テーブルに変更
   - `UserAccountManager.swift`: ログイン後にAPNsトークン登録を要求

3. **Lambda側修正**
   - `role='owner'`条件を完全に削除
   - 観測対象デバイス（device_id）に紐づく全ユーザーの`user_id`を取得
   - 各ユーザーの`apns_token`をチェックし、最初に見つかったトークンを使用

**修正後のフロー**:
```
Lambda処理完了（観測対象デバイスのdevice_idを受け取る）
  ↓
device_id から user_devices テーブルを検索（roleに関係なく）
  ↓
user_id のリストを取得
  ↓
各 user_id について users.apns_token をチェック
  ↓
最初に見つかったトークンで通知先デバイス（iPhone）にプッシュ通知送信
```

---

### 問題7: CustomUserDataによるEndpoint属性エラー（2025-10-15）
**エラー**: `InvalidParameterException: Endpoint already exists with the same Token, but different attributes`

**原因**:
- SNS Endpointの`CustomUserData`に**観測対象デバイスのdevice_id**を保存していた
- 1人のユーザーが複数の観測対象デバイスを所有している場合、同じAPNsトークンで異なる`CustomUserData`を持つEndpointを作成しようとする
- 例：
  - 観測対象デバイス1（d067d407...）の処理 → `CustomUserData: {"device_id": "d067d407..."}`
  - 観測対象デバイス2（9f7d6e27...）の処理 → `CustomUserData: {"device_id": "9f7d6e27..."}` ← 属性エラー

**解決**:
1. **Lambda関数修正**
   - `create_or_update_endpoint`関数から`CustomUserData`を完全に削除
   - APNsトークンのみでEndpointを作成（1ユーザーにつき1つのEndpoint）

2. **既存Endpointのクリーンアップ**
   - AWS SNS Consoleから古いEndpointを手動削除
   - 次回のLambda実行時に、新しいEndpointが1つだけ作成される

**修正後の動作**:
```
観測対象デバイス1の処理 → user_id取得 → APNsトークン取得 → Endpoint作成（CustomUserDataなし）
観測対象デバイス2の処理 → user_id取得 → APNsトークン取得 → 既存Endpoint使用（属性一致）
```

**重要な教訓**:
- **SNS Endpointは通知先デバイス（iPhone）ごとに1つ**
- **観測対象デバイス（録音デバイス）の情報をEndpointに保存してはいけない**
- **用語の明確化が必須**：「デバイス」という言葉の曖昧さが設計ミスの原因

---

## 📋 データベース構造

### usersテーブル（2025-10-14修正）

```sql
-- APNsトークンの保存先をusersテーブルに変更
ALTER TABLE public.users
ADD COLUMN apns_token TEXT;

CREATE INDEX idx_users_apns_token ON public.users(apns_token);

-- 旧devicesテーブルのカラムを削除
ALTER TABLE public.devices DROP COLUMN IF EXISTS apns_token;
DROP INDEX IF EXISTS idx_devices_apns_token;
```

**設計変更の理由：**
- APNsトークン = **通知先デバイス（このユーザーが使っているiPhone）**を識別
- 観測対象デバイス（録音デバイス：松本遍、松本正弦など）とは無関係
- 正しい保存先：`public.users.apns_token`（1ユーザーにつき1つ）

**現在の状態**: ✅ カラム追加済み、トークン保存済み

**データ例**:
```sql
-- ユーザーテーブル（通知先デバイスのAPNsトークンを保存）
users:
  user_id: 164cba5a-dba6-4cbc-9b39-4eea28d98fa5
  apns_token: 7cb89fa1198f12001efa...  ← 通知先デバイス（iPhone）のトークン

-- 観測対象デバイステーブル（録音デバイス）
devices:
  device_id: d067d407-cf73-4174-a9c1-d91fb60d64d0  ← 松本遍のApple Watch
  device_id: 9f7d6e27-98c3-4c19-bdfb-f7fda58b9a93  ← 松本正弦のApple Watch

-- ユーザーと観測対象デバイスの紐付け
user_devices:
  user_id: 164cba5a-dba6-4cbc-9b39-4eea28d98fa5
  device_id: d067d407-cf73-4174-a9c1-d91fb60d64d0
  role: owner

  user_id: 164cba5a-dba6-4cbc-9b39-4eea28d98fa5
  device_id: 9f7d6e27-98c3-4c19-bdfb-f7fda58b9a93
  role: owner
```

→ 複数の観測対象デバイスからデータが送られても、プッシュ通知は**1台の通知先デバイス（iPhone）にのみ送信される**

---

## 🧪 テスト状況

### ✅ 完全動作確認済み（2025-10-15）

#### Lambda側
- ✅ APNsトークン取得処理: 実装完了（`users`テーブルから取得）
- ✅ `role`条件削除: 完了（全ユーザーに対応）
- ✅ Endpoint自動作成: 実装済み（CustomUserDataなし）
- ✅ Endpoint自動削除・再作成: 実装済み
- ✅ IAM権限: `SNS:DeleteEndpoint`追加済み
- ✅ CloudWatch Logs: 詳細ログ出力中
- ✅ プッシュ通知送信: **動作確認済み**

#### iOS側
- ✅ デバイストークン取得: 成功
- ✅ トークン保存: 成功（`users.apns_token`に保存済み）
- ✅ ログイン後のトークン登録: 実装完了
- ✅ プッシュ通知ハンドラー: 実装済み
- ✅ トーストバナー表示: 実装済み（フォアグラウンド時）
- ✅ プッシュ通知受信: **動作確認済み**
- ✅ フォアグラウンド時の自動データ更新: **動作確認済み**

#### 動作確認ログ（2025-10-15）
```
📬 [PUSH] サイレント通知受信
📱 [PUSH] アプリ状態: フォアグラウンド
🔄 [PUSH] ダッシュボード更新通知: deviceId=d067d407-cf73-4174-a9c1-d91fb60d64d0, date=2025-10-15
🔄 [PUSH] RefreshDashboard notification received
🗑️ [PUSH] Today's cache cleared
🔄 [PUSH] Reloading today's data...
✅ [RPC] Successfully fetched all dashboard data
```

- ✅ 複数の観測対象デバイス（d067d407, 9f7d6e27）からの通知が同じ通知先デバイス（iPhone）に正常に届く
- ✅ トーストバナー表示後、データが自動更新される

---

## 🔄 次のステップ

### 1. 動作確認（最優先）

#### テスト手順
1. **次の30分スロット（18:00、18:30など）でLambda実行を待つ**
2. **CloudWatch Logsで以下を確認**:
   ```
   [PUSH] Step 1: Getting all user_ids for device: ...
   [PUSH] Found N user(s) for device: [...]
   [PUSH] Step 2: Getting APNs token for user: ...
   [PUSH] ✅ APNs token found for user: ..., token: 7cb89fa1...
   [PUSH] ✅ Push notification sent successfully
   ```
3. **iOSアプリでプッシュ通知受信を確認**
   - フォアグラウンド時: トーストバナー表示
   - バックグラウンド時: 通知バナー表示

#### 未解決の問題
- ⚠️ バックグラウンドスレッドから`@Published`プロパティを更新している警告（大量）
  - 場所: `UserAccountManager.swift`のトークンリフレッシュ処理
  - 影響: 現時点では動作に問題なし（警告のみ）
  - 修正: `MainActor`で囲む必要あり

---

### 2. テスト完了後の作業

#### サイレント通知に戻す
現在はテスト用に通常の通知（バナー表示）を使用。本番運用時はサイレント通知に変更：

```python
message = {
    'APNS_SANDBOX': json.dumps({
        'aps': {
            'content-available': 1  # サイレント通知のみ
        },
        'device_id': device_id,
        'date': date,
        'action': 'refresh_dashboard'
    })
}
```

#### 本番環境への切り替え
TestFlightまたはApp Store公開時：
```python
SNS_PLATFORM_APP_ARN = 'arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app'  # Production
message = {'APNS': json.dumps({...})}  # APNS_SANDBOX → APNS
```

---

### 2. 環境自動切り替え（推奨）

環境変数で自動切り替え：

```python
import os

# 環境判定
ENV = os.environ.get('ENV', 'development')  # development | production

if ENV == 'production':
    SNS_PLATFORM_APP_ARN = 'arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app'
    MESSAGE_KEY = 'APNS'
else:
    SNS_PLATFORM_APP_ARN = 'arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-sandbox'
    MESSAGE_KEY = 'APNS_SANDBOX'
```

---

## 💰 コスト見積もり

### AWS SNS
- **料金**: 100万メッセージまで無料、以降$0.50/100万メッセージ
- **使用量**: 48回/日 × 30日 = 1,440回/月
- **月額コスト**: $0（無料枠内）

### APNs
- Appleからの課金なし（無料）

---

## 📚 参考資料

- [AWS SNS APNs連携](https://docs.aws.amazon.com/sns/latest/dg/sns-mobile-application-as-subscriber.html)
- [Apple Push Notifications](https://developer.apple.com/documentation/usernotifications)
- [Swift UserNotifications](https://developer.apple.com/documentation/usernotifications)

---

## 🔧 トラブルシューティング

### プッシュ通知が届かない場合

1. **CloudWatch Logsを確認**
   - ログストリームに`[PUSH] ✅ Push notification sent successfully`があるか
   - エラーログがないか

2. **SNS Endpointの状態を確認**
   - AWS Console → SNS → Applications → Endpoints
   - ステータスが「有効」になっているか

3. **iOSアプリの権限を確認**
   - 設定 → 通知 → アプリ名 → 通知を許可

4. **環境の一致を確認**
   - Xcodeビルド → Sandbox環境
   - TestFlight/App Store → Production環境

---

## 🚨 未解決問題（2025-10-14 23:10 JST）

### 症状：特定デバイスのみプッシュ通知が届かない

**発生状況**：
- ✅ **正常動作デバイス**: `9f7d6e27-98c3-4c19-bdfb-f7fda58b9a93` - 全処理が成功し、dashboard_summaryが更新される
- ❌ **失敗デバイス**: `d067d407-cf73-4174-a9c1-d91fb60d64d0` - 22:00以降、dashboard_summaryが更新されない（18:30で停止）

**重要な事実**：
1. **同じ時刻（22:00）に両デバイスが処理されている**
2. **両デバイスとも同じユーザー（user_id: 164cba5a...）、同じrole（owner）**
3. **音声長**: 失敗デバイス=10秒、成功デバイス=60秒（短い方が失敗）
4. **処理内容による差はないはず**（AIが判断）
5. **今日の18:30まで失敗デバイスも正常動作していた**
6. **本日の変更**: Lambda環境変数を`anon`キー → `service_role`キーに変更

---

### 調査済み事項

#### ✅ 調査済み（問題なし）
1. **user_devicesテーブル**: 両デバイスとも同じ設定（role=owner）
2. **dashboard-analysis-worker**: service_roleキーで正常動作（手動テスト成功）
3. **dashboard-summary-worker**: 正常動作（成功デバイスのログで確認）
4. **Vibe Scorer API (`/analyze-dashboard-summary`)**: 手動テストで成功（26秒で完了）

#### ❌ 問題箇所の特定

**audio-worker（watchme-audio-worker）が原因**：

```
22:00の処理（CloudWatch Logs）:
- 成功デバイス（9f7d6e27）:
  "vibe_scorer": {"status_code": 200, "success": true}
  → "Triggering dashboard summary" メッセージあり

- 失敗デバイス（d067d407）:
  "vibe_scorer": {"status_code": 504, "success": false}
  → "Triggering dashboard summary" メッセージなし
```

**コード（lambda_function.py:46）**:
```python
# Vibe Scorerが成功した場合、累積分析キューにメッセージを送信
if results.get('vibe_scorer', {}).get('success'):
    trigger_dashboard_summary(device_id, date, time_slot)
```

**処理フロー**:
```
audio-worker
  ↓
vibe_scorer API (/vibe-scorer/analyze-timeblock) 呼び出し
  ↓
失敗デバイス: 504エラー → success=false
  ↓
dashboard-summary-queueにメッセージ送信されず
  ↓
dashboard-summary-worker 起動せず
  ↓
dashboard-analysis-worker 起動せず
  ↓
プッシュ通知送信されず
```

---

### 核心的な謎（未解決）

**なぜ特定デバイスだけvibe_scorer APIが504エラーになるのか？**

**既知の事実**：
1. 呼び出しエンドポイント: `POST /vibe-scorer/analyze-timeblock`
2. タイムアウト設定: audio-workerは180秒、nginxは60秒
3. **504は「処理が60秒以上かかった」ではない可能性**
   - 実際にAPIがエラーを返している
   - タイムアウト後もバックエンド処理は継続するはずだが、データベースにデータが入っていない
   - つまり、**APIレベルで処理が失敗している**

**除外された可能性**：
- ❌ RLSポリシー（service_roleキーで回避済み）
- ❌ user_devicesのrole制限（両方owner）
- ❌ 音声長（短い方が失敗するのは逆）
- ❌ 処理内容の差（AIが判断）

**過去の類似問題**：
- 以前、デバイスのowner/visitor制限で特定デバイスが弾かれる問題があった
- 原因は「隠れた仕様」だった

---

### 検証が必要な仮説

1. **vibe_scorer APIの内部処理**
   - 特定デバイスIDまたはデータで失敗する条件がないか？
   - `/vibe-scorer/analyze-timeblock` エンドポイントのコードを確認
   - 手動でcurlテストして、実際のエラーレスポンスを確認

2. **audio-workerの条件分岐**
   - 特定デバイスを除外する隠れた条件がないか？
   - `/Users/kaya.matsumoto/projects/watchme/server-configs/lambda-functions/watchme-audio-worker/lambda_function.py` を再確認

3. **dashboardテーブルのデータ**
   - 22:00のタイムブロックデータが正常に保存されているか？
   - promptフィールドに問題がないか？

4. **他のデバイスでテスト**
   - 複数デバイスで検証し、成功/失敗のパターンを特定

---

### 次のステップ（優先順位順）

1. **vibe_scorer API (`/vibe-scorer/analyze-timeblock`) を手動テスト**
   ```bash
   # d067d407デバイスの22:00データで実際にAPIを呼び出す
   # promptをdashboardテーブルから取得して送信
   # エラーレスポンスの詳細を確認
   ```

2. **EC2サーバーのVibe Scorer APIログを確認**
   ```bash
   ssh -i /Users/kaya.matsumoto/watchme-key.pem ubuntu@3.24.16.82
   docker logs api-gpt-v1 --tail 500 --since 3h | grep "d067d407"
   # d067d407のリクエストが来ているか？
   # エラーログがあるか？
   ```

3. **audio-workerを修正（暫定対策）**
   ```python
   # vibe_scorerの成功/失敗に関わらず、dashboard-summaryキューに送信
   # 修正箇所: lambda_function.py:46
   trigger_dashboard_summary(device_id, date, time_slot)
   ```

4. **複数デバイスで検証**
   - 他のデバイスIDでテストし、成功/失敗のパターンを特定
   - デバイス固有の問題か、データ内容の問題かを切り分け

---

### ファイルパス

**Lambda関数**:
- audio-worker: `/Users/kaya.matsumoto/projects/watchme/server-configs/lambda-functions/watchme-audio-worker/lambda_function.py`
- dashboard-summary-worker: `/Users/kaya.matsumoto/projects/watchme/server-configs/lambda-functions/watchme-dashboard-summary-worker/lambda_function.py`
- dashboard-analysis-worker: `/Users/kaya.matsumoto/projects/watchme/server-configs/lambda-functions/watchme-dashboard-analysis-worker/lambda_function.py`

**Vibe Scorer API**:
- ローカル: `/Users/kaya.matsumoto/api_gpt_v1/main.py`
- EC2サーバー: `/home/ubuntu/api_gpt_v1/`（Dockerコンテナ: `api-gpt-v1`）

**SSH接続**:
```bash
ssh -i /Users/kaya.matsumoto/watchme-key.pem ubuntu@3.24.16.82
```

---

### データベース確認クエリ

```bash
# service_roleキーで確認
SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTM4MDMzMCwiZXhwIjoyMDY2OTU2MzMwfQ.8KrfVB5F7fWPYiX2r4FneVwylBDYvMYtHNcUjDD2ri4"

# dashboard_summary確認
curl -s 'https://qvtlwotzuzbavrzqhyvt.supabase.co/rest/v1/dashboard_summary?device_id=eq.d067d407-cf73-4174-a9c1-d91fb60d64d0&date=eq.2025-10-14&select=*' \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"

# dashboard（22:00のタイムブロック）確認
curl -s 'https://qvtlwotzuzbavrzqhyvt.supabase.co/rest/v1/dashboard?device_id=eq.d067d407-cf73-4174-a9c1-d91fb60d64d0&date=eq.2025-10-14&time_block=eq.22-00&select=*' \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"
```

---

## 📝 修正履歴

### 2025-10-15（00:43 JST）
- ✅ **完全解決**: プッシュ通知が正常に動作
- ✅ **根本原因の発見**: `CustomUserData`に観測対象デバイスのdevice_idを保存していたため、属性エラーが発生
- ✅ Lambda関数修正：`CustomUserData`を完全に削除
- ✅ IAM権限追加：`SNS:DeleteEndpoint`を追加
- ✅ 用語の標準化：「観測対象デバイス（録音デバイス）」と「通知先デバイス（iPhone）」を明確に区別
- ✅ ドキュメント大幅更新：用語定義、アーキテクチャ図、解決した問題を追加

### 2025-10-14（23:10 JST）
- ✅ Lambda環境変数を`service_role`キーに変更
- ✅ dashboard-analysis-workerを修正（API失敗時でもプッシュ通知送信）
- ✅ データベース設計変更：APNsトークンを`devices`→`users`テーブルに移行
- ✅ iOS側実装：ログイン後のトークン登録処理を追加
- ✅ Lambda側実装：`role='owner'`条件を削除、全ユーザーに対応
- ✅ トーストバナー表示機能を追加

---

*最終更新: 2025-10-15 00:43 JST*
