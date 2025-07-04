# Supabase Swift Package Setup Guide

## 📦 Supabase Swift ライブラリの追加

### 1. Xcodeでの設定手順

1. **Xcodeでプロジェクトを開く**
   ```
   ios_watchme_v9.xcodeproj を開く
   ```

2. **Swift Package Manager でパッケージを追加**
   - `File` → `Add Package Dependencies...` をクリック
   - 以下のURLを入力:
   ```
   https://github.com/supabase/supabase-swift
   ```

3. **バージョン設定**
   - `Dependency Rule`: `Up to Next Major Version`
   - `Version`: `2.0.0` (またはそれ以上)

4. **パッケージ選択**
   - `Supabase` パッケージを選択
   - `Add to Target`: `ios_watchme_v9` を選択

### 2. コード有効化手順

#### DeviceManager.swift の修正

1. **import文を有効化**
   ```swift
   // コメントアウトを削除
   import Supabase
   ```

2. **Supabaseクライアント初期化を有効化**
   ```swift
   // init()内のコメントアウトを削除
   self.supabase = SupabaseClient(
       supabaseURL: URL(string: supabaseURL)!,
       supabaseKey: supabaseAnonKey
   )
   ```

3. **ライブラリ利用可能判定を変更**
   ```swift
   private func isSupabaseLibraryAvailable() -> Bool {
       return true  // falseからtrueに変更
   }
   ```

4. **Supabase Insert実装を有効化**
   ```swift
   // registerDeviceToSupabase()内のコメントアウトを削除
   ```

### 3. 実装後のテスト

1. **ビルド確認**
   ```bash
   Command + B でビルドエラーがないことを確認
   ```

2. **動作確認**
   - アプリ起動時にSupabaseデバイス登録が実行されることを確認
   - ログに "✅ Supabaseデバイス登録成功" が表示されることを確認

### 4. 期待される動作

#### Supabase `devices` テーブルへのInsert
```sql
INSERT INTO devices (
    platform_identifier,
    device_type,
    platform_type,
    owner_user_id
) VALUES (
    'D67BE0C9-0EAE-41B3-A20C-5F55889A65DF',  -- identifierForVendor
    'ios_virtual_mic',
    'iOS',
    '164cba5a-dba6-4cbc-9b39-4eea28d98fa5'    -- 認証ユーザーID
);
```

#### 音声アップロード時の送信データ
```
POST https://api.hey-watch.me/upload
- user_id: 認証ユーザーID
- timestamp: 録音日時
- device_id: Supabaseから返されたUUID  ← 新規追加
- file: 音声ファイル
```

## 🔧 トラブルシューティング

### Package追加でエラーが発生する場合
1. Xcodeを再起動
2. `Product` → `Clean Build Folder`
3. パッケージキャッシュをクリア

### ビルドエラーが発生する場合
1. iOS Deployment Target が14.0以上であることを確認
2. Supabaseライブラリの最新バージョンを使用

### 認証エラーが発生する場合
1. Supabase RLS ポリシーが正しく設定されているか確認
2. anon keyが正しいか確認

## 📋 実装完了チェックリスト

- [ ] Supabase Swift パッケージ追加完了
- [ ] import Supabase 有効化
- [ ] Supabaseクライアント初期化有効化  
- [ ] isSupabaseLibraryAvailable() → true に変更
- [ ] registerDeviceToSupabase() 実装有効化
- [ ] ビルドエラーなし
- [ ] デバイス登録動作確認
- [ ] 音声アップロード時のdevice_id送信確認

---

**この手順完了後、iOS WatchMeアプリは完全にSupabase devicesテーブルと連携したデバイス登録機能を持つことになります。**