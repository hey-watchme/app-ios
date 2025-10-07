# トラブルシューティング

WatchMe iOSアプリでよく発生する問題と解決策をまとめています。

---

## ビルドエラー

### "Missing package product 'Supabase'" エラー

パッケージ依存関係の解決に失敗している場合の対処法：

#### 1. クリーンアップスクリプトの実行

```bash
cd /Users/kaya.matsumoto/ios_watchme_v9
./reset_packages.sh
```

#### 2. Xcodeでの操作

1. Xcodeを完全に終了
2. Xcodeを再起動してプロジェクトを開く
3. `File → Packages → Reset Package Caches`
4. `File → Packages → Resolve Package Versions`
5. `Product → Clean Build Folder` (Shift+Cmd+K)
6. `Product → Build` (Cmd+B)

#### 3. それでも解決しない場合

1. Project Navigatorでプロジェクトを選択
2. Package Dependenciesタブを選択
3. Supabaseパッケージを削除（−ボタン）
4. +ボタンでパッケージを再追加：`https://github.com/supabase/supabase-swift`

### "Duplicate GUID reference" エラー

プロジェクトファイルに重複した参照がある場合：

```bash
# DerivedDataを削除
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Xcodeキャッシュをクリア
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# プロジェクトをクリーンビルド
```

---

## 認証・ログイン関連

### 「このメールアドレスは既に登録されています」

既に登録済みのメールアドレスを使用しています。

**解決策**: ログイン画面から既存アカウントでログイン

### 「パスワードは8文字以上」

パスワードが短すぎます。

**解決策**: パスワードを8文字以上に設定

### 「パスワードが一致しません」

パスワード確認欄の入力が一致していません。

**解決策**: パスワード確認欄を正しく入力

### 登録ボタンを押しても画面遷移しない

会員登録処理が正しく完了していない可能性があります。

**デバッグ手順**:
1. Xcodeのコンソールでログを確認
2. 「✅ ログイン成功」が出ているか確認
3. 「🔍 isAuthenticated変更検知: false → true」が出ているか確認
4. 上記が出ていない場合は、`UserAccountManager.swift`の`performSignIn`メソッドを確認

---

## データ表示関連

### デバイスデータが取得できない

#### 1. 認証状態の確認

```swift
// DeviceManagerのログで確認
"✅ 認証済みユーザー: [ID]" または "❌ 認証されていません"
```

#### 2. RLSポリシーの確認

- `user_devices`テーブルにRLSが有効か確認
- 適切なポリシーが設定されているか確認

#### 3. 一度ログアウトして再ログイン

古い認証情報が残っている可能性があります。

### "Decoded user_devices count: 0" エラー

認証トークンが正しく設定されていない可能性があります。

**解決策**:
1. SupabaseAuthManagerが標準のSDKメソッドを使用しているか確認
2. DeviceManagerがグローバルsupabaseクライアントを使用しているか確認
3. checkAuthStatusでセッション復元が正しく行われているか確認

### すべての日付で同じデータが表示される

RPC関数が日付パラメータを正しく処理していない可能性があります。

**確認手順**:

1. **RPC関数の実装確認**
   - `get_dashboard_data`関数が`p_date`パラメータを正しく処理しているか
   - WHERE句で日付フィルタリングが適用されているか
   - 日付比較が正しい形式（YYYY-MM-DD）で行われているか

2. **データベースの確認**
   ```sql
   -- 各テーブルに異なる日付のデータが存在するか確認
   SELECT date, COUNT(*) FROM dashboard_summary
   WHERE device_id = 'your-device-id'
   GROUP BY date
   ORDER BY date DESC;
   ```

3. **デバッグ方法**
   - Xcodeのコンソールで送信されているパラメータを確認
   - Supabaseのダッシュボードで直接RPC関数をテスト

---

## タイムゾーン関連

### 日付がずれる、異なるタイムゾーンのデバイスで表示がおかしい

**原因と解決策**:

#### 1. Calendar.currentの使用を確認

- ❌ 問題: `Calendar.current`はiPhoneのタイムゾーン
- ✅ 解決: `deviceManager.deviceCalendar`を使用

#### 2. UTC変換の確認

- ❌ 問題: データをUTCに変換している
- ✅ 解決: デバイスのローカル時間のまま保存

#### 3. デバイス切り替え時の問題

- 確認: `DeviceManager.selectedDeviceTimezone`が正しく取得されているか
- 確認: 各Viewが`@EnvironmentObject`でDeviceManagerを参照しているか

#### 4. データベースの確認

```sql
-- デバイスのタイムゾーンが設定されているか確認
SELECT device_id, timezone FROM devices WHERE device_id = 'your-device-id';

-- タイムゾーンがNULLの場合は更新
UPDATE devices SET timezone = 'Asia/Tokyo' WHERE device_id = 'your-device-id';
```

#### 5. デバッグ方法

```swift
// 現在のデバイスタイムゾーンを確認
print("Device Timezone: \(deviceManager.selectedDeviceTimezone)")

// キャッシュキーを確認（日付が正しいか）
print("Cache Key: \(makeCacheKey(deviceId: deviceId, date: date))")
```

### file_pathの日付とグラフ表示の日付が一致しない

**原因**: Vault APIでのfile_path生成時とiOSアプリでの表示時でタイムゾーンが異なる

**解決策**:
1. Vault APIが`recorded_at`のタイムゾーンを保持しているか確認
2. file_pathの日付部分がデバイスのローカル日付になっているか確認
3. iOS側で`SlotTimeUtility.getDateString`にタイムゾーンを渡しているか確認

---

## 録音・アップロード関連

### 録音が開始されない

**原因**: マイク権限が許可されていない

**解決策**:
1. iPhoneの「設定」→「WatchMe」→「マイク」をONにする
2. アプリを再起動

### アップロードが失敗する

**確認事項**:
1. ネットワーク接続を確認
2. サーバーURLが正しいか確認：`https://api.hey-watch.me/upload`
3. Xcodeのコンソールでエラーログを確認

**よくあるエラー**:
- `401 Unauthorized`: 認証トークンが無効
- `413 Payload Too Large`: ファイルサイズが大きすぎる
- `500 Internal Server Error`: サーバー側の問題

---

## アバター関連

### アバターが表示されない

**確認事項**:
1. Avatar Uploader APIの稼働状態を確認
   ```bash
   curl http://3.24.16.82:8014/health
   ```

2. S3のURL形式を確認
   ```
   https://watchme-avatars.s3.ap-southeast-2.amazonaws.com/...
   ```

3. Xcodeコンソールでアップロードログを確認

### アバターアップロードが失敗する

**よくあるエラー**:
- `401 Unauthorized`: Supabase認証トークンが無効
- `400 Bad Request`: ファイル形式が不正（JPEG/PNGのみ対応）
- `413 Payload Too Large`: 画像サイズが大きすぎる（リサイズが必要）

---

## デバイス管理関連

### デバイスが見つからない

#### 1. ユーザーに紐付くデバイスが本当に存在するか確認

```sql
SELECT * FROM user_devices WHERE user_id = 'ユーザーID';
```

#### 2. デバイス情報の確認

```sql
SELECT * FROM devices WHERE device_id = 'デバイスID';
```

#### 3. データが存在するか確認

```sql
SELECT * FROM dashboard_summary WHERE device_id = 'デバイスID';
```

### QRコードスキャンでデバイス追加ができない

**確認事項**:
1. QRコードの内容がUUID形式になっているか
2. デバイスIDがデータベースに存在するか
3. カメラ権限が許可されているか

---

## パフォーマンス関連

### アプリ起動が遅い

**実機での起動時間**: 約5秒（業界標準レベル）

- システム処理（dyldリンカー + ライブラリロード）: 約5秒
- アプリ初期化処理: 0.04秒

**注意**: シミュレーターでは約13秒かかります（Rosetta変換のオーバーヘッド）

**これ以上の短縮には機能削除が必要**（トレードオフ）

### データ読み込みが遅い

**確認事項**:
1. RPC関数が正しく実装されているか
2. ネットワーク接続が安定しているか
3. データベースに大量のデータが蓄積されていないか

---

## データベース関連のエラー

### RLSポリシーエラー

```
Error: new row violates row-level security policy
```

**原因**: Row Level Securityポリシーに違反しています。

**解決策**:
1. 該当テーブルのRLSポリシーを確認
2. 認証状態を確認（`auth.uid()`が正しく取得されているか）
3. 必要に応じてポリシーを修正

### 外部キー制約エラー

```
Error: insert or update on table violates foreign key constraint
```

**原因**: 参照先のレコードが存在しません。

**解決策**:
1. 参照先のテーブルにレコードが存在するか確認
2. IDが正しいか確認
3. `public.users(user_id)`を参照しているか確認（`auth.users(id)`ではない）

---

## デバッグ方法

### ログの確認

アプリケーションは詳細なログを出力します：

- 🚀 アップロード開始
- ✅ アップロード成功
- ❌ エラー発生
- 📊 タイムゾーン情報
- 🔍 デバイスID確認
- 📱 デバイス登録状態

### ネットワーク通信の確認

Xcodeのネットワークデバッガーを使用して、送信されるリクエストの内容を確認できます。

### データベースクエリの確認

VIBEデータが見つからない場合の確認手順：

```swift
// 1. 選択中のデバイスIDを確認
print("Selected Device ID: \(deviceManager.selectedDeviceID ?? "nil")")
```

```sql
-- 2. Supabaseでデータ存在確認
SELECT * FROM devices WHERE device_id = 'デバイスID';

SELECT * FROM dashboard_summary WHERE device_id = 'デバイスID';
```

---

## よくある質問

### Q. メール確認は必要ですか？

A. いいえ、現在はメール確認を無効化しています（v9.31.0〜）。会員登録後すぐに利用開始できます。

### Q. 複数のiPhoneから同じデバイスを見ることはできますか？

A. はい、可能です。デバイスIDは物理的なiPhoneに紐付きません。どのiPhoneからでも、同じデバイスIDを選択すれば同じデータにアクセスできます。

### Q. タイムゾーンを変更するとデータはどうなりますか？

A. 既存のデータはそのままです。タイムゾーンを変更すると、以降の録音と表示が新しいタイムゾーンで行われます。

### Q. 録音データはどこに保存されますか？

A. S3ストレージに保存されます。ローカルには一時的に保存され、アップロード完了後に削除されます。

---

## サポート

上記で解決しない場合は、以下の情報を含めて開発者に連絡してください：

1. Xcodeのコンソールログ
2. エラーメッセージのスクリーンショット
3. 再現手順
4. 使用しているデバイス・iOSバージョン
