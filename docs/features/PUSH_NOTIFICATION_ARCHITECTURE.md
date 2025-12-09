# WatchMe プッシュ通知仕様書

**最終更新**: 2025-12-09

---

## ⚠️ 今後の予定

**証明書方式（.p12）→ トークン方式（.p8）への移行を予定**

**現状の問題**:
- 証明書方式では、Production/Sandbox別々のPlatform Applicationが必要
- Lambda環境変数を手動で切り替える必要がある（TestFlight/Xcode直接インストールの切り替え）

**トークン方式のメリット**:
- 1つのトークンでProduction/Sandbox両方に対応
- 環境変数の切り替え不要
- 有効期限なし（証明書は1年ごとに更新が必要）
- Apple推奨方式（2021年以降）

**移行手順**: このドキュメント末尾に記載予定

---

## 📊 システム概要

Lambda処理完了後、iOSアプリにリアルタイムでデータ更新を通知します。

**技術スタック**: AWS SNS + Apple Push Notification service (APNs)

---

## 🏗️ アーキテクチャ

```
観測対象デバイス（録音） → Lambda処理 → SNS → APNs → 通知先デバイス（iPhone）
                                                      ↓
                                            トーストバナー表示
                                                      ↓
                                            データ自動更新
```

**データフロー**:
1. 観測対象デバイス（録音デバイス）から音声データ送信
2. Lambda処理完了後、プッシュ通知送信
3. 通知先デバイス（iPhone）でデータ自動更新

---

## 📖 用語定義

| 用語 | 説明 | データベース |
|------|------|------------|
| **観測対象デバイス（録音デバイス）** | 音声データを収集するデバイス | `devices`テーブル |
| **通知先デバイス（iPhone）** | プッシュ通知を受信するユーザーのiPhone | - |
| **APNsトークン** | 通知先デバイスを一意に識別するトークン | `users.apns_token` |

**重要**: 1ユーザーは複数の観測対象デバイスを所有できますが、通知先デバイスは1台のみです。

---

## ⚙️ 環境設定

### 開発環境（Sandbox）

**用途**: Xcodeから直接インストールしたアプリ

| 項目 | 値 |
|------|-----|
| **Platform Application** | `watchme-ios-app-sandbox` |
| **ARN** | `arn:aws:sns:ap-southeast-2:754724220380:app/APNS_SANDBOX/watchme-ios-app-sandbox` |
| **証明書** | Sandbox用APNs証明書 |
| **Lambda設定** | `SNS_PLATFORM_APP_ARN = 'arn:aws:sns:.../APNS_SANDBOX/...'` |

### 本番環境（Production）

**用途**: TestFlight/App Store公開版

| 項目 | 値 |
|------|-----|
| **Platform Application** | `watchme-ios-app` |
| **ARN** | `arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app` |
| **証明書** | Production用APNs証明書（有効期限: 2026-11-12） |
| **Lambda設定** | `SNS_PLATFORM_APP_ARN = 'arn:aws:sns:.../APNS/...'` |

---

## 🔧 Lambda関数実装

**ファイル**: `/Users/kaya.matsumoto/projects/watchme/server-configs/production/lambda-functions/watchme-dashboard-analysis-worker/lambda_function.py`

### プッシュ通知送信処理

```python
# 1. SupabaseからAPNsトークン取得
apns_token = get_user_apns_token(device_id)

# 2. SNS Platform Endpoint作成/更新
endpoint_arn = create_or_update_endpoint(device_id, apns_token)

# 3. プッシュ通知送信
message = {
    'APNS_SANDBOX': json.dumps({  # 本番: 'APNS'
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

### トークン取得フロー

```python
# device_id → user_id → apns_token
user_devices = get_user_devices(device_id)  # roleに関係なく全ユーザー取得
for user_id in user_devices:
    apns_token = get_apns_token(user_id)  # users.apns_token から取得
    if apns_token:
        return apns_token
```

---

## 📱 iOS側実装

### デバイストークン取得・保存

**ファイル**: `ios_watchme_v9App.swift`

```swift
// AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
func application(_ application: UIApplication,
                didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    saveDeviceToken(token)  // Supabase users.apns_token に保存
}
```

### プッシュ通知ハンドラー

```swift
// AppDelegate.userNotificationCenter(_:willPresent:)
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    // 1. 認証チェック
    guard UserDefaults.standard.string(forKey: "current_user_id") != nil else {
        return []
    }

    // 2. デバイスフィルター（選択中デバイスのみ）
    if let targetDeviceId = userInfo["device_id"] as? String {
        let selectedDeviceId = UserDefaults.standard.string(forKey: "watchme_selected_device_id")
        guard targetDeviceId == selectedDeviceId else {
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
ALTER TABLE public.users
ADD COLUMN apns_token TEXT;

CREATE INDEX idx_users_apns_token ON public.users(apns_token);
```

**設計理由**: APNsトークンは通知先デバイス（iPhone）を識別するため、`users`テーブルに保存。

---

## 🔧 トラブルシューティング

### プッシュ通知が届かない場合

#### 1. XcodeのSigning設定を確認（最頻出）

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

3. **ビルド＆実行**
   ```bash
   xcodebuild -scheme ios_watchme_v9 -destination 'id=<device_id>' clean build
   ```

**発生頻度**: macOSアップデート後、Xcodeバージョンアップ後に発生（数ヶ月〜1年に1回程度）

---

#### 2. Push Notificationsが有効か確認

**Xcode > Target > Signing & Capabilities**

- 「Push Notifications」が追加されているか確認
- なければ「+ Capability」から追加

---

#### 3. Lambda側のログ確認

```bash
aws logs tail /aws/lambda/watchme-dashboard-analysis-worker --since 1h --filter-pattern "[PUSH]"
```

**確認ポイント**:
```
[PUSH] ✅ APNs token found for user: ...
[PUSH] ✅ Push notification sent successfully: <MessageId>
```

---

#### 4. APNs環境の一致を確認

| アプリインストール方法 | 必要な環境 | Lambda環境変数 |
|---------------------|-----------|-----------|
| Xcode直接インストール | Sandbox | `APNS_ENVIRONMENT=sandbox` |
| TestFlight/App Store | Production | `APNS_ENVIRONMENT=production` |

**現在の本番設定**: `APNS_ENVIRONMENT=production`（TestFlight/App Store用に固定）

**Xcode直接インストールでテストする場合**:
```bash
aws lambda update-function-configuration \
  --function-name watchme-dashboard-analysis-worker \
  --environment "Variables={APNS_ENVIRONMENT=sandbox,SUPABASE_URL=...,SUPABASE_KEY=...,API_BASE_URL=...}" \
  --region ap-southeast-2
```

**注意**: 本番環境では常に `production` を使用することを推奨します。Xcode版のテストはTestFlightを使用してください。

---

#### 5. iOS側のログ確認

**Xcodeコンソールで以下が出ているか確認**:

**✅ 正常な場合**:
```
📬 [PUSH] Foreground notification received
📬 [PUSH-MANAGER] Notification handled:
   Type: refresh_dashboard
   Device: e33f212e-72a1-4de3-80fa-f9bed75704c7
   Date: 2025-11-27
🍞 [Toast] 表示: デバイス e33f212e の2025-11-27のデータ分析が完了しました✨
```

**❌ 異常な場合**:
```
⚠️ [PUSH] Notification ignored (user not authenticated)
⚠️ [PUSH] Notification ignored (different device: ...)
```

→ 認証状態またはデバイス選択状態を確認

---

#### 6. AWS SNS Platform Application のステータス確認

**重要**: Platform Applicationが無効になっているとプッシュ通知が送信されません。

**AWS Console確認手順**:
1. AWS Console → SNS → Applications
2. `watchme-ios-app` (Production) または `watchme-ios-app-sandbox` (Sandbox) を選択
3. **ステータスが「有効」になっているか確認**

**無効の場合**:
- 「編集」ボタン → ステータスを「有効」に変更 → 保存

**CLI確認**:
```bash
aws sns get-platform-application-attributes \
  --platform-application-arn arn:aws:sns:ap-southeast-2:754724220380:app/APNS/watchme-ios-app \
  --region ap-southeast-2
```

**無効になる原因**:
- 証明書が期限切れ
- APNsサーバーへの接続が連続で失敗

---

#### 7. APNs証明書の有効期限確認

**Apple Developer Portal**: https://developer.apple.com/account/resources/certificates/list

- Sandbox証明書: 有効期限を確認
- Production証明書: 有効期限 2026-11-12

**期限切れの場合**: 証明書を再発行してAWS SNSに再アップロード

---

#### 8. Supabaseのトークン確認

```sql
SELECT user_id, apns_token FROM users WHERE user_id = '<user_id>';
```

- `apns_token`が保存されているか確認
- 空の場合: ログイン後に自動保存されるため、再ログイン

---

## 🧪 動作確認手順

### 1. 開発環境での確認

1. **Xcodeでアプリをビルド＆実行**
2. **アプリを起動したまま（フォアグラウンド）**
3. **新しい録音をアップロード**
4. **約2-3分後、プッシュ通知を確認**
   - トーストバナーが表示される
   - データが自動更新される

### 2. Xcodeコンソールログで確認

```
📬 [PUSH] Foreground notification received
✨ [PUSH] Haptic feedback triggered
🗑️ [PUSH] Cache cleared: <device_id>_<date>
📊 [Direct Access] Fetching daily_results
✅ [Direct Access] Daily results found
🍞 [Toast] 表示: ...
```

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

## 📚 関連ファイル

### Lambda関数
- `/Users/kaya.matsumoto/projects/watchme/server-configs/production/lambda-functions/watchme-dashboard-analysis-worker/lambda_function.py`

### iOS実装
- `ios_watchme_v9/ios_watchme_v9App.swift` - AppDelegate
- `ios_watchme_v9/Services/PushNotificationManager.swift` - 通知処理
- `ios_watchme_v9/DeviceManager.swift` - トークン保存

---

*最終更新: 2025-11-27*
