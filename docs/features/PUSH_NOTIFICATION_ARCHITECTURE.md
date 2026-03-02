# WatchMe プッシュ通知仕様書

**最終更新**: 2025-12-11

---

## ✅ Token認証方式への移行完了

**2025-12-11に証明書方式（.p12）からトークン方式（.p8）へ移行完了**

### 移行のメリット

✅ **環境自動判定**: XcodeとTestFlightを切り替えても、Lambda関数が自動的に適切な環境を選択
✅ **有効期限なし**: 証明書は1年ごとに更新が必要だったが、トークンは無期限
✅ **Apple推奨方式**: 2021年以降の推奨方式
✅ **運用が簡単**: 手動での環境変数切り替えが不要

---

## 📊 システム概要

Lambda処理完了後、iOSアプリにリアルタイムでデータ更新を通知します。

**技術スタック**: AWS SNS + Apple Push Notification service (APNs) + Token認証

---

## 🏗️ アーキテクチャ

```
分析対象デバイス（録音） → Lambda処理 → 環境判定 → SNS → APNs → 通知先デバイス（iPhone）
                                        ↓                      ↓
                                  sandbox/production    トーストバナー表示
                                                              ↓
                                                        データ自動更新
```

**データフロー**:
1. 分析対象デバイス（録音デバイス）から音声データ送信
2. Lambda処理完了後、プッシュ通知送信
3. **DBから環境情報（sandbox/production）を自動取得**
4. 適切なSNS Platform Applicationを選択
5. 通知先デバイス（iPhone）でデータ自動更新

---

## 📖 用語定義

| 用語 | 説明 | データベース |
|------|------|------------|
| **分析対象デバイス（録音デバイス）** | 音声データを収集するデバイス | `devices`テーブル |
| **通知先デバイス（iPhone）** | プッシュ通知を受信するユーザーのiPhone | - |
| **APNsトークン** | 通知先デバイスを一意に識別するトークン | `users.apns_token` |
| **APNs環境** | sandbox（開発）/ production（本番） | `users.apns_environment` |

**重要**: 1ユーザーは複数の分析対象デバイスを所有できますが、通知先デバイスは1台のみです。

---

## ⚙️ 環境設定

### 開発環境（Sandbox）

**用途**: Xcodeから直接インストールしたアプリ

| 項目 | 値 |
|------|-----|
| **Platform Application** | `watchme-ios-app-token-sandbox` |
| **ARN** | `arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-token-sandbox` |
| **認証方法** | Token（.p8ファイル） |
| **自動選択条件** | `users.apns_environment = 'sandbox'` |

### 本番環境（Production）

**用途**: TestFlight/App Store公開版

| 項目 | 値 |
|------|-----|
| **Platform Application** | `watchme-ios-app-token` |
| **ARN** | `arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app-token` |
| **認証方法** | Token（.p8ファイル） |
| **自動選択条件** | `users.apns_environment = 'production'` |

### 共通設定

| 項目 | 値 |
|------|-----|
| **Bundle ID** | `com.watchme.watchme` |
| **Team ID** | `TG68TFXG88` |
| **認証キー** | .p8ファイル（同一ファイルを両環境で使用） |

---

## 🔧 Lambda関数実装

**ファイル**: `/Users/kaya.matsumoto/projects/watchme/server-configs/production/lambda-functions/watchme-dashboard-analysis-worker/lambda_function.py`

### 環境自動判定の仕組み

```python
# 1. SupabaseからAPNsトークンと環境を取得
apns_token, apns_environment = get_user_apns_token(device_id)
# 戻り値: ('139753291c880ecbf90e...', 'sandbox')
# または: ('ecaf39096153b4d40f5a...', 'production')

# 2. 環境に応じたPlatform Application ARNを自動選択
platform_arn = (
    SNS_PLATFORM_APP_ARN_SANDBOX if apns_environment == 'sandbox'
    else SNS_PLATFORM_APP_ARN_PRODUCTION
)

# 3. SNS Platform Endpoint作成/更新
endpoint_arn = create_or_update_endpoint(device_id, apns_token, apns_environment)

# 4. プッシュ通知送信
message = {
    'APNS_SANDBOX' if apns_environment == 'sandbox' else 'APNS': json.dumps({
        'aps': {
            'alert': {
                'body': f"{subject_name}さんの{local_date}のデータ分析が完了しました✨"
            },
            'sound': 'default',
            'content-available': 1
        },
        'device_id': device_id,
        'date': local_date,
        'action': 'refresh_dashboard'
    })
}

sns_client.publish(
    TargetArn=endpoint_arn,
    Message=json.dumps(message),
    MessageStructure='json'
)
```

### トークン・環境取得フロー

```python
def get_user_apns_token(device_id):
    """
    Returns: (apns_token, apns_environment) or (None, None)
    """
    # device_id → user_id → (apns_token, apns_environment)
    user_devices = get_user_devices(device_id)
    for user_id in user_devices:
        response = supabase.from("users").select("apns_token,apns_environment").eq("user_id", user_id)
        apns_token = response[0].get('apns_token')
        apns_environment = response[0].get('apns_environment', 'production')  # デフォルトは production
        if apns_token:
            return (apns_token, apns_environment)
    return (None, None)
```

---

## 📱 iOS側実装

### デバイストークン取得・保存（環境自動判定）

**ファイル**: `ios_watchme_v9/DeviceManager.swift`

```swift
private func saveAPNsTokenToSupabase(_ token: String) {
    guard let userId = UserDefaults.standard.string(forKey: "current_user_id") else {
        print("⚠️ [PUSH] ユーザーIDが見つかりません")
        UserDefaults.standard.set(token, forKey: "pending_apns_token")
        return
    }

    // ビルド設定から環境を自動判定
    #if DEBUG
    let environment = "sandbox"
    #else
    let environment = "production"
    #endif

    Task {
        do {
            try await supabase
                .from("users")
                .update([
                    "apns_token": token,
                    "apns_environment": environment  // ← 環境情報も保存
                ])
                .eq("user_id", value: userId)
                .execute()

            print("✅ [PUSH] APNsトークン保存成功: userId=\(userId), token=\(token.prefix(20))..., environment=\(environment)")
        } catch {
            print("❌ [PUSH] APNsトークン保存失敗: \(error)")
        }
    }
}
```

**仕組み**:
- Xcodeから実行（Debug） → `environment = "sandbox"`
- TestFlightから実行（Release） → `environment = "production"`
- **開発者の手動操作は不要（完全自動）**

### プッシュ通知ハンドラー

**ファイル**: `ios_watchme_v9App.swift`

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    let userInfo = notification.request.content.userInfo

    // 1. 認証チェック
    guard UserDefaults.standard.string(forKey: "current_user_id") != nil else {
        print("⚠️ [PUSH] Notification ignored (user not authenticated)")
        return []
    }

    // 2. デバイスフィルター（選択中デバイスのみ）
    if let targetDeviceId = userInfo["device_id"] as? String {
        let selectedDeviceId = UserDefaults.standard.string(forKey: "watchme_selected_device_id")
        guard targetDeviceId == selectedDeviceId else {
            print("⚠️ [PUSH] Notification ignored (different device)")
            return []
        }
    }

    // 3. PushNotificationManagerに処理を委譲
    PushNotificationManager.shared.handleAPNsPayload(userInfo)

    return [.banner, .sound]
}
```

---

## 🗄️ データベース設計

### usersテーブル

```sql
-- APNsトークンカラム（既存）
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS apns_token TEXT;

-- APNs環境カラム（2025-12-11追加）
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS apns_environment TEXT DEFAULT 'production';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_users_apns_token ON public.users(apns_token);
```

**設計理由**:
- `apns_token`: 通知先デバイス（iPhone）を識別
- `apns_environment`: Lambda関数が適切なSNS Platform Applicationを自動選択するために使用

---

## 🔧 トラブルシューティング

### プッシュ通知が届かない場合

#### 1. 環境情報がDBに保存されているか確認

```sql
SELECT user_id, apns_token, apns_environment, updated_at
FROM users
WHERE user_id = '<user_id>';
```

**期待される結果**:
- Xcode実行時: `apns_environment = 'sandbox'`
- TestFlight実行時: `apns_environment = 'production'`
- `updated_at` が最近であること（古い場合はアプリを再起動）

**修正方法**:
```sql
-- 手動で更新（一時的な対処）
UPDATE users
SET apns_environment = 'sandbox',  -- または 'production'
    updated_at = NOW()
WHERE user_id = '<user_id>';
```

---

#### 2. Lambda側のログ確認

```bash
aws logs tail /aws/lambda/watchme-dashboard-analysis-worker --since 1h --filter-pattern "[PUSH]" --region ap-southeast-2
```

**✅ 正常な場合**:
```
[PUSH] ✅ APNs token found for user: ..., token: 139753..., environment: sandbox
[PUSH] Using Platform Application: arn:.../APNS_SANDBOX/watchme-ios-app-token-sandbox (environment: sandbox)
[PUSH] ✅ Push notification sent successfully: <MessageId>
```

**❌ 異常な場合**:
```
[PUSH] No APNs token found for device: ...
[PUSH] ❌ Failed to re-enable or send after re-enable: Endpoint is disabled
```

→ Supabaseのトークンが古い、または環境が不一致

---

#### 3. XcodeのSigning設定を確認（最頻出）

**症状**: データは届くがプッシュ通知が届かない

**原因**: Apple IDがサインアウトされている、Teamが「Unknown name」になっている

**解決手順**:

1. **Xcode > Settings > Accounts**
   - Apple IDが追加されているか確認
   - なければ「+」ボタンからApple IDを追加

2. **プロジェクト > Signing & Capabilities**
   - 「Team」のプルダウンで正しいTeamを選択
   - 「Unknown name」が消えることを確認
   - 「Automatically manage signing」にチェックが入っていることを確認

3. **アプリを再ビルド**

---

#### 4. Push Notificationsが有効か確認

**Xcode > Target > Signing & Capabilities**

- 「Push Notifications」が追加されているか確認
- なければ「+ Capability」から追加

---

#### 5. AWS SNS Platform Application のステータス確認

**重要**: Platform Applicationが無効になっているとプッシュ通知が送信されません。

**AWS Console確認手順**:
1. AWS Console → SNS → Applications
2. `watchme-ios-app-token` (Production) または `watchme-ios-app-token-sandbox` (Sandbox) を選択
3. **ステータスが「有効」になっているか確認**

**CLI確認**:
```bash
# Production
aws sns get-platform-application-attributes \
  --platform-application-arn arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app-token \
  --region ap-southeast-2

# Sandbox
aws sns get-platform-application-attributes \
  --platform-application-arn arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-token-sandbox \
  --region ap-southeast-2
```

**無効になる原因**:
- APNsサーバーへの接続が連続で失敗
- トークンファイル（.p8）の設定ミス

---

#### 6. iOS側のログ確認

**Xcodeコンソールで以下が出ているか確認**:

**✅ 正常な場合（アプリ起動時）**:
```
✅ [PUSH] APNsトークン保存成功: userId=..., token=139753..., environment=sandbox
```

**✅ 正常な場合（通知受信時）**:
```
📬 [PUSH] Foreground notification received
📬 [PUSH-MANAGER] Notification handled:
   Type: refresh_dashboard
   Device: e33f212e-72a1-4de3-80fa-f9bed75704c7
   Date: 2025-12-11
🍞 [Toast] 表示: 松本正弦さんの2025-12-11のデータ分析が完了しました✨
```

**❌ 異常な場合**:
```
⚠️ [PUSH] Notification ignored (user not authenticated)
⚠️ [PUSH] Notification ignored (different device: ...)
```

→ 認証状態またはデバイス選択状態を確認

---

#### 7. APNsトークンが古い場合

**症状**: 4ヶ月前のトークンが保存されている

**原因**: アプリの再インストール、iOSアップデート後にトークンが更新されていない

**解決方法**:
1. アプリを完全終了
2. アプリを再起動
3. Xcodeコンソールで `✅ [PUSH] APNsトークン保存成功` を確認

---

## 🧪 動作確認手順

### 1. 開発環境（Xcode）での確認

1. **Xcodeでアプリをビルド＆実行**
2. **Xcodeコンソールで環境を確認**:
   ```
   ✅ [PUSH] APNsトークン保存成功: ..., environment=sandbox
   ```
3. **新しい録音をアップロード**（またはObserverデバイスで自動録音）
4. **約2-3分後、プッシュ通知を確認**
   - トーストバナーが表示される
   - データが自動更新される

### 2. 本番環境（TestFlight）での確認

1. **TestFlightからアプリをインストール＆起動**
2. **Supabaseで環境を確認**:
   ```sql
   SELECT apns_environment FROM users WHERE user_id = '<user_id>';
   -- 結果: production
   ```
3. **新しい録音をアップロード**
4. **約2-3分後、プッシュ通知を確認**

---

## 🎯 通知フィルタリング

### フォアグラウンド（アプリ起動中）

- ✅ **選択中デバイス**の通知 → トーストバナー表示
- ❌ **選択外デバイス**の通知 → 無視

### バックグラウンド（アプリ閉じている）

- ✅ **全デバイス**の通知 → 通知センターに表示（フィルタリングなし）

---

## 💰 コスト

- **AWS SNS**: 無料枠内（月1,440回程度）
- **APNs**: 無料

---

## 🔄 環境切り替えフロー（完全自動）

```
開発者の操作: Xcodeでビルド
  ↓
iOS側: #if DEBUG → environment = "sandbox"
  ↓
Supabase: apns_environment = "sandbox" を保存
  ↓
Lambda: DBから "sandbox" を取得
  ↓
Lambda: SNS_PLATFORM_APP_ARN_SANDBOX を使用
  ↓
APNs: Sandbox環境で通知送信 ✅

---

開発者の操作: TestFlightからインストール
  ↓
iOS側: #else → environment = "production"
  ↓
Supabase: apns_environment = "production" を保存
  ↓
Lambda: DBから "production" を取得
  ↓
Lambda: SNS_PLATFORM_APP_ARN_PRODUCTION を使用
  ↓
APNs: Production環境で通知送信 ✅
```

**開発者の手動作業: ゼロ（完全自動）**

---

## 📚 関連ファイル

### Lambda関数
- `/Users/kaya.matsumoto/projects/watchme/server-configs/production/lambda-functions/watchme-dashboard-analysis-worker/lambda_function.py`

### iOS実装
- `ios_watchme_v9/ios_watchme_v9App.swift` - AppDelegate
- `ios_watchme_v9/Services/PushNotificationManager.swift` - 通知処理
- `ios_watchme_v9/DeviceManager.swift` - トークン保存・環境判定

### AWS SNS
- Production: `arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app-token`
- Sandbox: `arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-token-sandbox`

---

## 📝 変更履歴

### 2025-12-11
- ✅ Token認証方式（.p8）への移行完了
- ✅ 環境自動判定機能の実装完了
- ✅ `users.apns_environment` カラム追加
- ✅ iOS側で `#if DEBUG` による環境自動判定実装
- ✅ Lambda関数で環境に応じたPlatform Application自動選択実装
- ✅ Sandbox用Platform Application作成

### 2025-12-09
- Token認証への移行計画策定

### 2025-11-27
- 証明書方式（.p12）での運用開始

---

*最終更新: 2025-12-11*
