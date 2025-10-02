# iOS WatchMe v9

WatchMeプラットフォームのiOSアプリケーション（バージョン9）。
音声録音とAI分析による心理・感情・行動の総合的なモニタリングを提供します。

## ✅ コメント機能（2025-09-16 完成）

観測対象に対してコメントを投稿・閲覧・削除できる機能を実装しました。

### 実装内容

1. **データベース設計**
   - `subject_comments`テーブル（作成済み）
   - RLSポリシー設定済み

2. **バックエンド実装**
   - RPC関数`get_dashboard_data`にコメント取得処理を追加
   - `public.users`テーブルからユーザー名とアバターを取得
   - 最新50件のコメントを新しい順に表示

3. **フロントエンド実装**
   - `SubjectComment.swift` - コメントモデル（name、avatar対応）
   - `SupabaseDataManager.swift` - CRUD メソッド
     - `addComment()` - コメント追加
     - `deleteComment()` - コメント削除  
     - `fetchComments()` - コメント取得
   - `SimpleDashboardView.swift` - UIコンポーネント
     - コメント一覧表示（ユーザー名とアバター付き）
     - コメント入力フォーム
     - 削除機能（自分のコメントのみ）

### 主な特徴
- ユーザー名の表示（`public.users.name`フィールド）
- ユーザーアバターの表示（`AvatarView`コンポーネント使用）
- リアルタイムでコメントの追加・削除が反映
- 自分のコメントのみ削除可能（RLSポリシーで制御）

## 🌟 主な機能

### 録音・データ収集
- **30分間隔の自動録音**: ライフログとして30分ごとに音声を自動録音
- **高品質録音設定**: 16kHz/16bit/モノラルで音声認識に最適化（v9.24.0〜）
  - `AVAudioQuality.high`による高品質録音でマイクゲインを最適化
  - `spokenAudio`モードで音声会話に特化した録音設定
  - マイクゲイン1.0（最大）で低音量問題を解決
  - **重要**: 従来の`measurement`モードから`spokenAudio`に変更（v9.24.1〜）
- **ストリーミングアップロード**: 大容量ファイルでも安定したアップロード
- **バックグラウンド処理**: アプリを閉じても録音・アップロードが継続

### 分析・レポート機能
- **ダッシュボード**: 日付ごとのデータを横スワイプで切り替え可能（v9.19.0〜）
  - **スワイプナビゲーション**: TabViewによる滑らかな日付切り替え
  - **過去1年分のデータ**: 1年前から今日までの日付範囲を表示
  - **モーダル詳細表示**: 各グラフカードをタップすると詳細画面がモーダルシートで表示
  - **日付表示の改善**（v9.23.0〜）:
    - 本日は「今日」と大きく表示し、実際の日付を小さく併記
    - 過去の日付は年・月日・曜日を階層的に表示
    - 日付セクションの背景を紫色（AppAccentColor）に統一
  - **カスタムカレンダー**（v9.23.0〜）: 気分の絵文字付きカレンダー表示
    - 月間の気分データを一覧表示
    - 各日付に気分スコアに応じた絵文字（👏✌️👍👌💪💔）を表示
    - データがない日は絵文字なしで日付のみ表示
- **心理グラフ (Vibe Graph)**: 時間ごとの詳細データをリスト表示（v9.25.0〜）
  - **時間詳細リスト**: dashboardテーブルから48スロット（30分間隔）のデータを表示
  - **コンパクトな表示**: 時間、スコア、サマリー1行目を1行に表示
  - **展開/折りたたみ**: タップで詳細サマリーを展開表示
  - **スコアによる色分け**: ポジティブ（緑）、ネガティブ（赤）、ニュートラル（グレー）
- **行動グラフ (Behavior Graph)**: 1日の行動パターンをランキングと時間帯別で可視化（v9.10.0〜）
- **感情グラフ (Emotion Graph)**: 8つの感情（Joy、Fear、Anger、Trust、Disgust、Sadness、Surprise、Anticipation）の時系列変化を折れ線グラフで表示（v9.10.0〜）

### ユーザー・デバイス管理
- **Supabase認証**: メールアドレスとパスワードによる安全な認証
- **マルチデバイス対応**: 1人のユーザーが複数のデバイスを管理可能
- **デバイス選択方式**: 物理デバイスとの紐付けなし、ユーザーがデバイスを選択するだけ（v9.29.0〜）
  - どのiPhoneからでも、好きなデバイスIDを選択して使用可能
  - バンドルID変更やアプリ再インストールの影響を受けない
- **QRコードによるデバイス追加**: QRコードスキャンで簡単にデバイスを追加（v9.15.0〜）
  - デバイス選択画面からカメラでQRコードをスキャン
  - **現在**: QRコード内容はdevice_idのみ（UUID形式）
  - **今後の予定**: QRコードにデバイスIDとタイムゾーン情報の両方を含める
    - デバイス追加時にタイムゾーン情報も正確に同期
    - QRコード生成側での対応も必要
  - デバイスIDの妥当性検証とデータベース存在確認
  - 成功・失敗時のポップアップフィードバック
  - デフォルト権限は「owner」で追加
- **タイムゾーン対応**: ユーザーのローカルタイムゾーンでの記録管理
- **ユーザープロフィール管理**: 
  - ニュースレター配信設定（ON/OFF）の管理
  - アバター画像のアップロード（Avatar Uploader API経由でS3に保存）
  - ユーザー情報（マイページ）からプロフィール設定を変更可能

### アバター機能（v9.20.0〜）
- **セキュアなアップロード**: Avatar Uploader API（http://3.24.16.82:8014）経由
  - クライアントにAWS認証情報を持たない安全な実装
  - Supabase認証トークンによる権限管理
- **対応アバタータイプ**:
  - ユーザーアバター（マイページ）
  - 観測対象アバター（Subject）
- **画像処理機能**:
  - カメラ撮影またはフォトライブラリから選択
  - 円形・正方形にトリミング（Mantisライブラリ使用 v9.21.0〜）
  - 自動リサイズ（サーバー側で512x512pxに最適化）
- **S3ストレージ**:
  - バケット: `watchme-avatars`（ap-southeast-2リージョン）
  - パブリックアクセス設定済み（画像の表示用）

### UI/UX改善（v9.25.0〜）
- **ログインフォームの標準化**: 入力欄とボタンの高さを44ptに統一（iOS Human Interface Guidelines準拠）
- **アプリカラーの統一**: メインアクションボタンにAppAccentColor（紫色）を適用
- **キーボード制御の最適化**: 
  - スクロール時に自動的にキーボードを閉じる
  - フォーム以外の部分をタップでキーボードを閉じる
  - 画面遷移時に自動的にキーボードを閉じる

### 通知機能（v9.22.0〜）
- **3種類の通知タイプ**:
  - **グローバル通知**: 全ユーザー向け（user_id = NULL, type = 'global'）
    - システムメンテナンス、新機能リリース、重要なお知らせなど
    - 既読管理は`notification_reads`テーブルで個別管理
  - **パーソナル通知**: 特定ユーザー向け（user_id = 対象ユーザー, type = 'personal'）
    - ユーザー固有の通知、アカウント関連の通知など
    - 既読管理は`notifications.is_read`フィールドで管理
  - **イベント通知**: イベント駆動型（user_id = 対象ユーザー, type = 'event'）
    - 分析完了、レポート生成、デバイス接続などのシステムイベント
    - 既読管理は`notifications.is_read`フィールドで管理
- **統一された通知画面**:
  - 3種類の通知を1つの画面で表示
  - 時系列順（新しい順）で統合表示
  - 通知タイプごとに異なるアイコンと色で視覚的に区別
- **既読管理**:
  - 個別既読: タップで既読化
  - 一括既読: 「すべて既読」ボタンで全通知を既読化
  - グローバル通知は`notification_reads`テーブルで既読状態を記録
- **未読バッジ表示**:
  - ヘッダーの通知アイコンに未読数を表示（最大99）
  - アプリ起動時とフォアグラウンド復帰時に自動更新
- **リアルタイム更新対応**:
  - Supabase Realtimeとの連携準備済み（将来実装予定）

## 重要：ユーザーIDとデバイスIDの関係

このアプリケーションでは、ユーザーとデバイスが以下の構造で管理されています：

### 認証とID管理の流れ

1. **ユーザー認証（SupabaseAuthManager）**
   - ユーザーはメールアドレスとパスワードでログイン
   - 認証成功時にユーザーID（UUID形式）が取得される
   - 例：`user_id: "123e4567-e89b-12d3-a456-426614174000"`

2. **デバイス選択（DeviceManager）**（v9.29.0で大幅変更）
   - **物理デバイスとの紐付けなし**：デバイスIDは「データの入れ物」として機能
   - ユーザーはデバイス設定画面で閲覧・録音したいデバイスを選択
   - どのiPhoneからでも、同じデバイスIDを選択すれば同じデータにアクセス可能
   - **疎結合設計**：バンドルID変更、アプリ再インストールの影響を受けない

3. **デバイスIDの管理**
   - `devices`テーブルに登録されたデバイスID（UUID形式）
   - `user_devices`テーブルでユーザーとデバイスの関係を管理
   - 例：`device_id: "d067d407-cf73-4174-a9c1-d91fb60d64d0"`

### データベース構造（v9.14.0で更新）

```sql
-- devicesテーブル
CREATE TABLE devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_type TEXT NOT NULL,
    timezone TEXT NOT NULL,  -- v9.17.0で追加（IANAタイムゾーン識別子）
    owner_user_id UUID REFERENCES auth.users(id),  -- 廃止予定
    subject_id UUID REFERENCES subjects(subject_id),  -- v9.14.0で追加
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- user_devicesテーブル（新規追加）
CREATE TABLE user_devices (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner', 'viewer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, device_id)
);

-- subjectsテーブル（v9.14.0で追加）
CREATE TABLE subjects (
    subject_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    age INTEGER,
    gender TEXT,
    avatar_url TEXT,
    notes TEXT,
    created_by_user_id UUID REFERENCES public.users(user_id) ON DELETE SET NULL,  -- public.usersを参照
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- subject_commentsテーブル（観測対象へのコメント）
CREATE TABLE subject_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES subjects(subject_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,  -- public.usersを参照
    comment_text TEXT NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- dashboard_summaryテーブル（統合ダッシュボードデータ）
CREATE TABLE dashboard_summary (
    device_id UUID NOT NULL,  -- devicesテーブルのdevice_idを参照
    date DATE NOT NULL,
    average_vibe REAL,                    -- 1日の平均気分スコア
    vibe_scores JSONB,                    -- 48個の時系列スコア配列（30分ごと、nullは0として扱う）
    burst_events JSONB,                   -- バーストイベント配列（感情の急変点）
    insights TEXT,                        -- 1日のサマリーインサイト
    analysis_result JSONB,                -- 詳細な分析結果
    processed_count INTEGER,              -- 処理済みブロック数
    last_time_block TEXT,                 -- 最後に処理した時間ブロック
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (device_id, date)
);

-- vibe_whisper_summaryテーブル（廃止済み）
-- 気分データはすべてdashboard_summaryテーブルから取得してください

-- notificationsテーブル（v9.22.0で追加）
CREATE TABLE notifications (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NULL REFERENCES public.users(user_id) ON DELETE CASCADE,  -- NULLの場合はグローバル通知、public.usersを参照
    type TEXT NOT NULL,  -- 'global', 'personal', 'event'
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NULL DEFAULT false,  -- パーソナル/イベント通知の既読フラグ
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT NOW(),
    triggered_by TEXT NULL,  -- イベントのトリガー元
    metadata JSONB NULL,  -- 追加情報
    CONSTRAINT notifications_pkey PRIMARY KEY (id)
);

-- notification_readsテーブル（グローバル通知の既読管理）（v9.22.0で追加）
CREATE TABLE notification_reads (
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,  -- public.usersを参照
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    read_at TIMESTAMP WITHOUT TIME ZONE NULL DEFAULT NOW(),
    CONSTRAINT notification_reads_pkey PRIMARY KEY (user_id, notification_id)
);
```

## 🚨 重要：認証とユーザー管理の設計原則

### ❌ 絶対に行ってはいけないこと

1. **auth.usersへの直接参照を作らない**
   - auth.usersはSupabaseの内部テーブル（直接アクセス不可）
   - すべての外部キー制約は`public.users(user_id)`を参照すること
   - `public.users.user_id`は`auth.users.id`のコピーとして機能

2. **新しいテーブル作成時の必須ルール**
   ```sql
   -- ❌ 間違い：auth.usersを直接参照
   CREATE TABLE new_table (
       user_id UUID REFERENCES auth.users(id)  -- 絶対NG！
   );
   
   -- ✅ 正しい：public.usersを参照
   CREATE TABLE new_table (
       user_id UUID REFERENCES public.users(user_id) ON DELETE CASCADE
   );
   ```

3. **iOS側のコード規則**
   ```swift
   // ❌ 間違い：auth.users.idを使用
   let userId = userAccountManager.currentUser?.id
   
   // ✅ 正しい：public.usersのuser_idを使用
   let userId = userAccountManager.currentUser?.profile?.userId
   ```

### なぜこの設計が必要か

1. **auth.usersはアクセス不可**：Supabaseの認証システムが管理、直接クエリ不可
2. **public.usersが仲介役**：アプリケーションが管理できるユーザー情報
3. **整合性の保証**：public.usersがauth.usersと連動（CASCADE DELETE）

#### RLS（Row Level Security）の重要性

**user_devicesテーブルには必ずRLSポリシーを設定してください：**

```sql
-- RLSを有効化
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のレコードのみアクセス可能
CREATE POLICY "Users can view their own device associations" ON user_devices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own device associations" ON user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 重要な注意点

- **一対多の関係**: 1人のユーザーが複数のデバイスを持つことができる
- **デバイスIDの永続性**: デバイスIDは一度生成されると変更されない
- **データの関連付け**: すべての音声データや分析結果はデバイスIDに紐付けられる
- **物理デバイス非依存**: デバイスIDは特定のiPhoneに紐付かない（v9.29.0〜）

### ID管理の詳細

#### ユーザーIDとデバイスIDの違い

1. **ユーザーID**
   - Supabase認証で生成されるUUID
   - メールアドレスとパスワードでログインすると取得
   - 例：`164cba5a-dba6-4cbc-9b39-4eea28d98fa5`
   - 1人のユーザーに1つのID

2. **デバイスID**
   - デバイス登録時にSupabaseが自動生成するUUID
   - 例：`d067d407-cf73-4174-a9c1-d91fb60d64d0`
   - 1つのユーザーが複数のデバイスを登録可能
   - VIBEデータなど、すべての分析データはこのIDに紐付く
   - **重要**: 物理的なiPhoneとは紐付かず、「データの入れ物」として機能

#### DeviceManagerで管理されるIDプロパティ（v9.29.0で簡素化）

DeviceManagerは以下の2つの主要なプロパティでデバイス情報を管理しています：

1. **`userDevices: [Device]`**
   - **役割**: 現在ログインしているユーザーに紐付けられている全てのデバイスのリスト
   - ユーザーが複数のデバイスを管理できるという要件を満たすために必須

2. **`selectedDeviceID: String?`**
   - **役割**: 現在アプリケーションのUI上で選択されているデバイスのID
   - グラフ表示・録音など、全ての操作で使用される唯一のデバイスID
   - userDevicesから選択されるか、デバイスが1つしかない場合は自動設定

#### 複数デバイスの管理

1. **デバイス選択UI**
   - ユーザーが複数デバイスを持つ場合、プルダウンで選択可能
   - 1つしかない場合は自動選択
   - 選択したデバイスのデータのみが表示される

2. **デバイス取得の流れ**
   ```swift
   // ログイン時に自動実行
   await deviceManager.fetchUserDevices(for: userId)

   // 取得したデバイスは以下で参照
   deviceManager.userDevices          // 全デバイスリスト
   deviceManager.selectedDeviceID     // 選択中のデバイスID
   ```

3. **データ取得時の注意**
   - 常に`selectedDeviceID`を使用
   - デバイスが選択されていない場合はエラー表示

### トラブルシューティング（ID関連）

#### デバイスが見つからない場合

1. **ユーザーに紐付くデバイスが本当に存在するか確認**
   ```sql
   SELECT * FROM devices WHERE owner_user_id = 'ユーザーID';
   ```

2. **VIBEデータが存在するか確認**
   ```sql
   SELECT * FROM vibe_whisper_summary WHERE device_id = 'デバイスID';
   ```

#### よくある間違い

- ❌ 削除されたプロパティ（`localDeviceIdentifier`, `isDeviceRegistered`）を使用（v9.29.0で削除）
- ✅ `selectedDeviceID`のみを使用（全ての操作で使用される唯一のデバイスID）

## 技術スタック

- **Swift 5.9+**
- **SwiftUI**
- **AVFoundation** - 音声録音
- **Supabase** - 認証とデータベース
- **Combine** - リアクティブプログラミング

## セットアップ

1. **Xcodeでプロジェクトを開く**
   ```bash
   open ios_watchme_v9.xcodeproj
   ```

2. **パッケージ依存関係の解決**
   - Xcode が自動的に Swift Package Manager の依存関係を解決します
   - Supabase SDK が自動的にインストールされます

3. **ビルドと実行**
   - ターゲットデバイスを選択
   - Run (Cmd + R) でアプリを実行

## アーキテクチャ

### ディレクトリ構造
```
ios_watchme_v9/
├── ios_watchme_v9App.swift        # アプリエントリーポイント
├── ContentView.swift              # メインビュー（シンプルな日付管理）
├── SimpleDashboardView.swift      # ダッシュボード（.task(id:)でデータ取得）
├── HomeView.swift                 # 心理グラフ（時間詳細リスト）表示
├── BehaviorGraphView.swift        # 行動グラフ
├── EmotionGraphView.swift         # 感情グラフ
├── RecordingView.swift            # 録音機能とファイル管理
├── LoginView.swift                # ログインUI
├── AudioRecorder.swift            # 録音管理
├── NetworkManager.swift           # API通信
├── DeviceManager.swift            # デバイス管理
├── SupabaseAuthManager.swift      # 認証管理
├── SupabaseDataManager.swift      # データ取得管理
├── AvatarView.swift               # アバター表示コンポーネント
├── AvatarPickerView.swift         # アバター選択・編集UI
├── AWSManager.swift               # Avatar Uploader APIクライアント
├── Configuration.swift            # API設定管理
├── Models/
│   ├── BehaviorReport.swift       # 行動レポートモデル
│   ├── EmotionReport.swift        # 感情レポートモデル
│   └── Subject.swift              # 観測対象モデル
├── DailyVibeReport.swift          # Vibeレポートモデル
├── DashboardTimeBlock.swift       # dashboardテーブルの時間ブロックモデル
├── DashboardSummary.swift         # dashboard_summaryテーブルのモデル
├── RecordingModel.swift           # 録音データモデル
├── SlotTimeUtility.swift          # 時刻スロット管理
├── Assets.xcassets/               # アプリアイコンとカラーセット
└── Info.plist                     # アプリ設定
```

### 主要コンポーネント

#### UI/ナビゲーション
1. **ドリルダウン構造**
   - **ContentView**: ダッシュボードビューで日付管理とスワイプナビゲーション
   - **TabViewスワイプ**: 左右スワイプで日付を切り替え（過去1年分）
   - **日付ナビゲーション**: 前日/次日ボタンとスワイプが連動
   - **モーダル詳細表示**: 各グラフはシートで表示（v9.19.0〜）

2. **データ取得の簡素化**
   - SwiftUIの`.task(id:)`モディファイアで日付変更を検知
   - 日付が変更されると自動的にデータを再取得
   - ViewModelやキャッシュシステムを使用しない
   - 各ビューが独立してデータを取得

3. **標準的なSwiftUIパターン**
   - `@State`による直接的な状態管理
   - `@EnvironmentObject`での共有オブジェクト管理
   - 複雑な状態管理ライブラリやパターンを避ける
   - SwiftUIの標準機能を最大限活用

#### データ管理
1. **AudioRecorder**
   - AVAudioRecorderを使用した録音機能
   - WAVフォーマットでの保存
   - 30分間隔での自動録音
   - **v9.24.1改善**: 音声会話に最適化された録音設定
     - `spokenAudio`モード: 音声会話の録音に特化
     - `AVAudioQuality.high`: 高品質録音で音量・明瞭度を向上
     - マイクゲイン1.0: 入力感度を最大に設定

2. **NetworkManager**
   - サーバーとの通信管理
   - ストリーミング方式によるメモリ効率的なアップロード（v9.7.0〜）
   - multipart/form-dataでのファイルアップロード
   - エラーハンドリングとリトライ機能

3. **SupabaseDataManager**（v9.18.0でシンプル化）
   - **データ取得**: `fetchAllReports`メソッドで必要なデータを取得
   - **RPC関数の活用**: `get_dashboard_data`で効率的にデータ取得
   - **シンプルな構造**: ViewModelパターンを使用せず、直接データを返す
   - **`.task(id:)`との連携**: 各ビューが独立してデータを取得

4. **認証・デバイス管理**
   - SupabaseAuthManager: ユーザー認証とセッション管理
   - DeviceManager: デバイス連携管理とデバイス選択（手動連携方式）

#### 環境オブジェクトパターン（v9.9.0〜）
アプリケーションのデータ管理は、SwiftUIの`@EnvironmentObject`パターンを使用してSingle Source of Truthを実現：

```swift
// アプリレベルでの初期化
@main
struct ios_watchme_v9App: App {
    @StateObject private var dataManager = SupabaseDataManager()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(dataManager)  // 環境に注入
        }
    }
}

// 各ビューでの利用
struct HomeView: View {
    @EnvironmentObject var dataManager: SupabaseDataManager  // 共有インスタンスを取得
    // ...
}
```

このアーキテクチャにより：
- **効率性**: 不要なAPIコールの削減
- **一貫性**: ビュー間でのデータ同期の自動化
- **拡張性**: 新しいグラフビューでも同じデータソースを利用可能

## ライフログツールとしての設計思想 🎯

### 観測対象中心の時間軸管理

本アプリケーションは**ライフログツール**として、観測対象（デバイスを装着している人）の生活リズムを正確に記録することを最重要視しています。

#### 基本原則

1. **デバイス = 観測対象の時間軸**
   - デバイスは特定の人（観測対象）の生活を記録する
   - そのデバイスが設置されている場所のタイムゾーンが基準
   - 観測対象が東京にいれば、朝7時の活動は「朝7時」として記録

2. **アカウント所有者の位置は無関係**
   - アカウント（ログインユーザー）は観測データを閲覧するだけ
   - アカウント所有者がアメリカにいても、東京のデバイスのデータは東京時間で表示
   - データの整合性と一貫性を保証

3. **タイムゾーンの固定性**
   - デバイスのタイムゾーンは登録時に設定され、基本的に変更されない
   - 旅行などの一時的な移動では変更しない（ライフログの一貫性のため）
   - 引っ越しなど恒久的な変更時のみ、設定から変更可能

#### 実装における重要な決定

- **データ保存**: デバイスのローカル時間で保存（UTCに変換しない）
- **データ表示**: 常にデバイスのタイムゾーンで表示
- **日付の境界**: デバイスのタイムゾーンでの0時が日付の境界

## API連携とデータフロー

### データ処理パイプライン

#### 1. 録音からグラフ表示までの完全なフロー

```
[iOS App] 
  ↓ 録音（30分ごと、デバイスのローカル時間）
  ↓
[Vault API]
  ↓ file_path生成: files/{device_id}/{date}/{time_slot}/audio.wav
  ↓ recorded_at: タイムゾーン付きタイムスタンプ（※将来廃止予定）
  ↓
[S3 Storage]
  ↓
[Lambda Function] ← 🆕 2025-09-22: S3イベントで即座に起動
  ↓ すべてのデバイスのオーディオファイルを自動処理
  ↓
[Whisper API / AST API / SUPERB API]
  ↓ 並列処理で音声分析
  ↓ file_pathから日付とtime_blockを抽出
  ↓ 各APIが結果をデータベースに保存
  ↓
[ChatGPT API]
  ↓ 感情分析とスコア生成
  ↓
[vibe_whisper_summary / dashboard_summary]
  ↓ 日次集計データ（48スロット）
  ↓
[iOS App]
  グラフ表示（デバイスのタイムゾーンで）
```

**🆕 2025-09-22 更新: Lambda関数によるリアルタイム処理**
- S3にオーディオファイルがアップロードされると即座にLambda関数が起動
- iPhone、オブザーバーを含むすべてのデバイスのファイルを自動処理
- 従来の1時間ごとのcron処理から、リアルタイム処理に改善

#### 2. file_pathの重要性と構造

##### 現在の構造
```
files/{device_id}/{YYYY-MM-DD}/{HH-MM}/audio.wav
```

- **device_id**: デバイスの識別子
- **YYYY-MM-DD**: デバイスのローカル日付
- **HH-MM**: 30分スロット（00-00, 00-30, ..., 23-30）

##### file_pathが信頼できる唯一の時間情報源である理由

1. **録音時点で確定**: デバイスのローカル時間で生成
2. **不変性**: 一度生成されたパスは変更されない
3. **通信遅延の影響なし**: ネットワーク遅延があってもパスは正確
4. **全処理で一貫**: Whisper、ChatGPT、グラフ表示まで同じパスを使用

##### 今後の構造化計画

```sql
-- 将来的な audio_files テーブル構造
CREATE TABLE audio_files (
    device_id UUID NOT NULL,
    local_date DATE NOT NULL,        -- デバイスのローカル日付
    time_slot VARCHAR(5) NOT NULL,   -- "HH-MM" 形式
    file_path TEXT NOT NULL,          -- 互換性のため残す
    -- recorded_at は廃止
    PRIMARY KEY (device_id, local_date, time_slot)
);
```

**メリット**:
- 高速なクエリ（日付・時間での検索が容易）
- データの一貫性保証
- タイムゾーン非依存で明確

#### 3. recorded_atカラムの問題と廃止予定

##### 現在の問題点
- グラフ生成では**一切使用されていない**
- 通信遅延により実際の録音時刻とずれる可能性
- file_pathの情報と重複
- 誤解を招く（使われていると思われがち）

##### 廃止計画
1. 短期: ドキュメントで非推奨として明記
2. 中期: 新規データでは記録しない
3. 長期: カラムを完全に削除

### データの流れ
1. **音声録音** → デバイスローカルにWAV形式で保存
2. **アップロード** → Vault API経由でS3に保存（file_path生成）
3. **Whisper処理** → 音声をテキストに変換、file_pathから日付・時間を抽出
4. **感情分析** → ChatGPTで感情スコアを生成
5. **集計保存** → `vibe_whisper_summary`テーブルに日次サマリーを保存
6. **データ取得** → アプリからデバイスIDと日付で分析結果を照会

### 高速データ取得（RPC実装）

本アプリケーションは、Supabaseのデータベース関数（RPC）を使用して、複数テーブルからのデータ取得を最適化しています。

#### 🚨 極めて重要: RPC関数は必須です！
**このアプリケーションはSupabase RPC関数 `get_dashboard_data` を使用しています。**
**RPC関数が存在しない、または正しく実装されていない場合、データが表示されません。**

⚠️ **2025年8月15日更新**: 
- 個別API呼び出しを廃止し、完全にRPC関数ベースに移行しました
- Subject（観測対象）情報もRPC関数から取得されます
- 個別取得メソッドは非推奨（@deprecated）となりました
- **レガシーメソッド削除完了**：195行のコード削除、保守性向上

#### 🔧 **改善予定（将来のリファクタリング）**
以下のファイルで非推奨メソッドを使用している箇所があります。将来的にRPC版に移行予定：

1. **ReportTestView.swift**
   - `fetchDailyReport` → `fetchAllReports`（RPC版）に変更予定
   - テスト用画面のため優先度低

2. **UserInfoView.swift** 
   - `fetchSubjectForDevice` → `fetchAllReports`（RPC版）に変更予定
   - マイページでの観測対象表示用、現在は警告表示済み

1. **統合データ取得関数 `get_dashboard_data`**
   - 単一のRPC呼び出しで全グラフデータを取得
   - dashboard_summary、behavior_summary、emotion_opensmile_summary、subjects、subject_commentsの5テーブルを一括取得
   - ネットワークリクエストが5回以上から1回に削減
   - **パラメータ**:
     - `p_device_id`: デバイスID（TEXT型、UUID形式）
     - `p_date`: 日付（TEXT型、YYYY-MM-DD形式）
   - **戻り値**: DashboardData型の配列（各テーブルのデータを含む）

#### 📝 必須: RPC関数の正しい実装

Supabaseの SQL Editor で以下のクエリを実行して、RPC関数を作成してください：

```sql
CREATE OR REPLACE FUNCTION get_dashboard_data(
    p_device_id TEXT,
    p_date TEXT
)
RETURNS TABLE (
    vibe_report JSONB,
    behavior_report JSONB,
    emotion_report JSONB,
    subject_info JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- 日付での絞り込み条件を含める（重要！）
        (SELECT to_jsonb(t) FROM vibe_whisper_summary t 
         WHERE t.device_id = p_device_id AND t.date = p_date::date 
         LIMIT 1) AS vibe_report,
        
        (SELECT to_jsonb(t) FROM behavior_summary t 
         WHERE t.device_id = p_device_id AND t.date = p_date::date 
         LIMIT 1) AS behavior_report,
        
        (SELECT to_jsonb(t) FROM emotion_opensmile_summary t 
         WHERE t.device_id = p_device_id AND t.date = p_date::date 
         LIMIT 1) AS emotion_report,
        
        -- subject_infoは日付に関係ないのでdevice_idのみで検索
        (SELECT to_jsonb(s) FROM subjects s
         JOIN devices d ON s.subject_id = d.subject_id
         WHERE d.device_id = p_device_id::uuid 
         LIMIT 1) AS subject_info;
END;
$$;
```

**⚠️ 注意事項:**
- 各テーブルのクエリで `AND t.date = p_date::date` の条件が必須です
- この条件がないと、すべての日付で同じデータが表示される不具合が発生します
- `p_date`パラメータは`TEXT`型で受け取り、`::date`でキャストして使用します

2. **SupabaseDataManagerの実装**
   ```swift
   // 🚀 RPCを使った高速データ取得（必須実装）
   func fetchAllReportsData(deviceId: String, date: Date) async -> DashboardData {
       let params = ["p_device_id": deviceId, "p_date": dateString]
       let response: [RPCDashboardResponse] = try await supabase.rpc("get_dashboard_data", params: params).execute().value
       // Subject情報も含めて一括取得
   }
   ```

3. **DashboardData構造体**
   ```swift
   struct DashboardData: Decodable {
       let behavior_report: BehaviorReport?     // behavior_summaryテーブルのデータ
       let emotion_report: EmotionReport?       // emotion_opensmile_summaryテーブルのデータ
       let subject_info: Subject?               // subjectsテーブルのデータ
       let dashboard_summary: DashboardSummary? // dashboard_summaryテーブルのデータ（気分データ含む）
       let subject_comments: [SubjectComment]?  // subject_commentsテーブルのデータ
   }
   ```

4. **パフォーマンスへの影響**
   - ダッシュボード表示の遅延を大幅に短縮
   - データの一貫性を保証（全データが同じタイミングで取得）
   - ネットワーク通信の効率化によりバッテリー消費も改善

#### 🔍 トラブルシューティング: すべての日付で同じデータが表示される場合

もし異なる日付を選択しても同じデータが表示される場合は、以下を確認してください：

1. **RPC関数の実装確認**
   - `get_dashboard_data`関数が`p_date`パラメータを正しく処理しているか
   - WHERE句で日付フィルタリングが適用されているか
   - 日付比較が正しい形式（YYYY-MM-DD）で行われているか

2. **データベースの確認**
   - 各テーブルに異なる日付のデータが存在するか
   - 日付カラムが正しい形式で保存されているか

3. **デバッグ方法**
   - Xcodeのコンソールで送信されているパラメータを確認
   - Supabaseのダッシュボードで直接RPC関数をテスト
   - 各テーブルのデータを個別に確認

#### 📈 RPC関数の拡張方法（今後の開発用）

新しいデータを追加する場合は、以下の手順で拡張してください：

1. **Supabase側（SQL）**：RPC関数に新しいフィールドを追加
   ```sql
   -- 例：新しいテーブルのデータを追加
   (SELECT to_jsonb(n) FROM new_table n 
    WHERE n.device_id = p_device_id AND n.date = p_date::date 
    LIMIT 1) AS new_report
   ```

2. **iOS側（Swift）**：構造体を更新
   ```swift
   // RPCDashboardResponseに新フィールドを追加
   struct RPCDashboardResponse: Codable {
       let vibe_report: DailyVibeReport?
       let behavior_report: BehaviorReport?
       let emotion_report: EmotionReport?
       let subject_info: Subject?
       let new_report: NewReport?  // 新規追加（オプショナル）
   }
   ```

3. **互換性の維持**
   - 新フィールドは必ずオプショナル（`?`）で定義
   - 既存フィールドの名前や型は変更しない
   - RPC関数のパラメータ名も変更しない

⚠️ **重要**: RPC関数の更新が必要な場合は、開発者に連絡してください。
Supabase側の更新と、iOS側の構造体更新が必要です。

### 心理グラフの実装（v9.25.0で大幅変更）

1. **HomeView（時間詳細リスト表示）**
   - dashboardテーブルから48スロットの時間データを取得
   - 各時間ブロックのvibe_scoreとsummaryを表示
   - コンパクトな1行表示（時間、スコア、サマリー1行目）
   - タップで詳細サマリーを展開/折りたたみ

2. **DashboardTimeBlock（データモデル）**
   - dashboardテーブルの時間ブロックごとのデータを管理
   - time_block、summary、vibe_scoreなどのフィールド
   - スコアによる色分け機能

3. **SupabaseDataManager**
   - `fetchDashboardTimeBlocks`メソッドでdashboardテーブルからデータ取得
   - デバイスIDと日付で絞り込み
   - 時間順でソート済みデータを返却

## API仕様

### アップロードエンドポイント
```
POST https://api.hey-watch.me/upload
Content-Type: multipart/form-data

Parameters:
- file: 音声ファイル (WAV形式)
- user_id: ユーザーID
- timestamp: 録音時刻 (ISO 8601形式、タイムゾーン情報付き)
  例: 2025-07-19T14:15:00+09:00
- metadata: デバイス情報とタイムスタンプを含むJSON
  {
    "device_id": "device_xxxxx",
    "recorded_at": "2025-07-19T14:15:00+09:00"
  }
```

### タイムゾーン処理の実装詳細 （v9.17.0〜）

本アプリケーションは、**デバイスのタイムゾーンを中心とした設計**を採用しています：

#### 1. タイムゾーン管理の階層

```
デバイス（観測対象の時間軸）
    ↓
DeviceManager（タイムゾーン管理）
    ↓
各UIコンポーネント（デバイスタイムゾーンで表示）
```

#### 2. DeviceManagerの拡張機能

```swift
// 選択中デバイスのタイムゾーン取得
var selectedDeviceTimezone: TimeZone {
    // devicesテーブルのtimezoneカラムから取得
    // フォールバック: TimeZone.current
}

// デバイス用のCalendar生成
var deviceCalendar: Calendar {
    var calendar = Calendar.current
    calendar.timeZone = selectedDeviceTimezone
    return calendar
}
```

#### 3. 実装された主要コンポーネントの修正

##### DatePagingView / DateNavigationView
- `Calendar.current`の使用を廃止
- `deviceManager.deviceCalendar`を使用
- 「今日」の判定もデバイスのタイムゾーンで実行

##### SlotTimeUtility
- UTC変換を削除
- タイムゾーンパラメータを追加
- デバイスのローカル時間でファイルパスを生成

##### SupabaseDataManager
- UTC変換を削除
- `fetchAllReports`にタイムゾーンパラメータを追加
- デバイスのタイムゾーンで日付文字列を生成

##### DashboardViewModel
- キャッシュキー生成でデバイスのタイムゾーンを使用
- データ取得時にタイムゾーンを明示的に渡す

#### 4. 録音時刻の記録

```swift
// AudioRecorderの実装
private func getDeviceTimezone() -> TimeZone {
    return deviceManager?.selectedDeviceTimezone ?? TimeZone.current
}

// ファイルパス生成時
let dateString = SlotTimeUtility.getDateString(from: Date(), timezone: getDeviceTimezone())
```

#### 5. 重要な設計決定

- **UTC変換の完全廃止**: データはデバイスのローカル時間で保存・処理
- **Calendar.currentの使用禁止**: 常にデバイスのCalendarを使用
- **タイムゾーンの明示的な管理**: 暗黙的なタイムゾーン使用を避ける

## 開発時の注意点

### 1. Supabase認証の重要事項 🚨

#### ❌ やってはいけないこと
```swift
// ⚠️ 手動でAPIを呼び出さない！
URLSession.shared.dataTask(with: "supabaseURL/auth/v1/token") { ... }
URLSession.shared.dataTask(with: "supabaseURL/rest/v1/table") { ... }
```

#### ✅ 正しい実装
```swift
// 🔐 認証: Supabase SDKの標準メソッドを使用
let session = try await supabase.auth.signIn(email: email, password: password)

// 📊 データ取得: SDKのクエリビルダーを使用
let data: [MyModel] = try await supabase
    .from("table_name")
    .select()
    .eq("column", value: "value")
    .execute()
    .value
```

#### 🔍 認証情報不整合問題の解決（v9.12.1で修正済み）
- **問題**: 手動API呼び出しではRLSポリシーを通過できない
- **解決**: 全てのデータアクセスをSDK標準メソッドに統一
- **効果**: 認証状態とデータアクセスの完全な整合性を実現

#### 認証状態の復元（アプリ再起動時）
```swift
// 保存されたトークンでセッションを復元
_ = try await supabase.auth.setSession(
    accessToken: savedUser.accessToken,
    refreshToken: savedUser.refreshToken
)
```

#### グローバルSupabaseクライアントの使用
```swift
// SupabaseAuthManager.swiftで定義されているグローバルインスタンスを使用
let supabase = SupabaseClient(...)  // グローバル定義

// 各クラスで独自のクライアントを作成しない！
// ❌ self.supabase = SupabaseClient(...)  // これはNG
```

### 2. RLS（Row Level Security）の設定

新しいテーブルを作成する際は、必ずRLSポリシーを設定してください：

1. **RLSを有効化**
2. **適切なポリシーを設定**（認証ユーザーのみアクセス可能など）
3. **テストユーザーでアクセス確認**

### 3. デバイス管理の新アーキテクチャ（v9.29.0で大幅簡素化）

- **デバイス選択方式**：
  - 物理デバイスとの紐付けを完全廃止
  - ユーザーはデバイス設定画面でデバイスを選択するだけ
  - どのiPhoneからでも、同じデバイスIDを選択すれば同じデータにアクセス可能
  - バンドルID変更やアプリ再インストールの影響を受けない
- **user_devicesテーブル**を経由してデバイスを管理
- ユーザーは複数デバイスを持てる（owner/viewerロール付き）
- `DeviceManager.fetchUserDevices`は以下の流れ：
  1. user_devicesテーブルからユーザーのデバイス一覧を取得
  2. devicesテーブルから詳細情報を取得
  3. role情報を付与してUIに反映

### 4. マイク権限
- Info.plistに`NSMicrophoneUsageDescription`が必要
- 初回起動時にユーザーに権限を求める

### 5. バックグラウンド処理
- Background Modesでaudioを有効化
- アップロードはバックグラウンドでも継続

### 6. ストレージ管理
- アップロード済みファイルの定期的な削除
- ディスク容量の監視

### 7. アバター機能の開発（v9.20.0〜）
- **API設定**: `Configuration.swift`でAvatar Uploader APIのエンドポイントを管理
  - 開発環境: `http://3.24.16.82:8014`（EC2直接）
  - 本番環境: `https://api.hey-watch.me/avatar`（Nginx経由、将来実装予定）
- **認証トークン**: `SupabaseAuthManager.getAccessToken()`でトークンを取得
- **エラーハンドリング**: `AWSManager`でHTTPステータスコードに応じた詳細なエラー処理
- **画像処理**: 大きい画像でのメモリ問題に注意（トリミング前のリサイズを検討）

### 8. 音声録音品質の最適化（v9.24.1〜）

#### 改善概要
従来の`measurement`モードと`AVAudioQuality.medium`から、音声会話に特化した設定に変更しました。これにより、AI分析に必要な明瞭な音声データの録音が可能になりました。

#### 技術的な改善点

1. **AVAudioSessionモードの変更**
   ```swift
   // 変更前（v9.24.0以前）
   try audioSession.setCategory(.record, mode: .measurement)
   
   // 変更後（v9.24.1〜）
   try audioSession.setCategory(.record, mode: .spokenAudio, options: [])
   ```
   - `measurement`モード: 測定機器向けの設定、音声会話には不適切
   - `spokenAudio`モード: 音声会話に最適化、ノイズリダクション強化

2. **録音品質の向上**
   ```swift
   // 変更前（v9.24.0以前）
   AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
   
   // 変更後（v9.24.1〜）
   AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
   ```
   - `medium`品質: 16kHz録音には不十分
   - `high`品質: より良い音量・明瞭度を実現

3. **マイクゲインの最適化**
   ```swift
   // 新規追加（v9.24.1〜）
   if audioSession.isInputGainSettable {
       try audioSession.setInputGain(1.0)  // 最大ゲイン
   }
   ```
   - デバイスがサポートしている場合、マイク入力感度を最大に設定
   - 低音量問題を根本的に解決

#### 期待される効果

1. **音量の向上**: マイクゲイン最大化により小さな声も確実に録音
2. **明瞭度の改善**: `spokenAudio`モードによるノイズ除去強化
3. **AI分析精度向上**: より良い音声データによる感情・行動分析の精度向上
4. **ユーザビリティ向上**: 録音の失敗や音量不足の問題を大幅に削減

### 9. ストリーミングアップロード仕様（v9.7.0〜）

#### 概要
従来の`Data(contentsOf:)`による一括メモリ読み込み方式から、ストリーミング方式に移行しました。これにより、ファイルサイズに関係なく安定したアップロードが可能になりました。

#### 技術仕様
1. **一時ファイル戦略**
   - multipart/form-dataのリクエストボディを一時ファイルとして構築
   - `FileManager.default.temporaryDirectory`に一時ファイルを作成
   - UUIDベースのユニークなファイル名で衝突を回避

2. **ストリーミングコピー**
   - 音声ファイルを64KB単位のチャンクで読み込み
   - FileHandleを使用したメモリ効率的なファイル操作
   - autoreleasepoolによるメモリの適切な解放

3. **URLSessionUploadTask**
   - `dataTask`から`uploadTask(with:fromFile:)`に変更
   - OSレベルでの効率的なファイルストリーミング
   - バックグラウンドでの安定した転送

4. **クリーンアップ処理**
   - アップロード完了後に一時ファイルを自動削除
   - deferブロックによる確実なリソース解放
   - エラー時も適切にクリーンアップ

#### メリット
- **メモリ効率**: ファイル全体をメモリに読み込まないため、大容量ファイルでも安定動作
- **信頼性向上**: メモリ不足によるアップロード失敗を完全に解消
- **パフォーマンス**: OSレベルの最適化により、効率的なデータ転送を実現

#### 実装例
```swift
// 一時ファイルへの書き込み
let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tmp")
let fileHandle = FileHandle(forWritingAtPath: tempFileURL.path)

// 64KBごとにストリーミングコピー
let bufferSize = 65536 // 64KB
while true {
    let chunk = audioFileHandle.readData(ofLength: bufferSize)
    if chunk.isEmpty { break }
    fileHandle.write(chunk)
}

// URLSessionUploadTaskでアップロード
let uploadTask = URLSession.shared.uploadTask(with: request, fromFile: tempFileURL) { data, response, error in
    // クリーンアップ
    defer { try? FileManager.default.removeItem(at: tempFileURL) }
    // レスポンス処理
}
```

### 9. Xcodeビルドエラーの対処

#### "Missing package product 'Supabase'" エラー

このエラーが発生した場合、以下の手順で解決できます：

1. **クリーンアップスクリプトの実行**
   ```bash
   ./reset_packages.sh
   ```

2. **Xcodeでの操作**
   - Xcodeを完全に終了
   - Xcodeを再起動してプロジェクトを開く
   - File → Packages → Reset Package Caches
   - File → Packages → Resolve Package Versions
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)

3. **それでも解決しない場合**
   - Project Navigator でプロジェクトを選択
   - Package Dependencies タブを選択
   - Supabase パッケージを削除（−ボタン）
   - +ボタンでパッケージを再追加：`https://github.com/supabase/supabase-swift`

#### "Duplicate GUID reference" エラー

プロジェクトファイルに重複した参照がある場合：

1. DerivedDataを削除
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```

2. Xcodeキャッシュをクリア
   ```bash
   rm -rf ~/Library/Caches/com.apple.dt.Xcode
   ```

3. プロジェクトをクリーンビルド

## トラブルシューティング

### 一般的な問題

- **録音が開始されない**: マイク権限を確認
- **アップロードが失敗する**: ネットワーク接続とサーバーURLを確認
- **認証エラー**: Supabaseの設定とAPIキーを確認
- **アバターが表示されない**: 
  - Avatar Uploader APIの稼働状態を確認（http://3.24.16.82:8014/health）
  - S3のURL形式を確認（`watchme-avatars.s3.ap-southeast-2.amazonaws.com`）
  - Xcodeコンソールでアップロードログを確認

### 認証・データアクセスの問題

#### デバイスデータが取得できない場合

1. **認証状態の確認**
   ```swift
   // DeviceManagerのログで確認
   "✅ 認証済みユーザー: [ID]" または "❌ 認証されていません"
   ```

2. **RLSポリシーの確認**
   - user_devicesテーブルにRLSが有効か確認
   - 適切なポリシーが設定されているか確認

3. **一度ログアウトして再ログイン**
   - 古い認証情報が残っている可能性
   - 新しい認証フローで問題解決

#### "Decoded user_devices count: 0"エラー

**原因**: 認証トークンが正しく設定されていない
**解決策**: 
1. SupabaseAuthManagerが標準のSDKメソッドを使用しているか確認
2. DeviceManagerがグローバルsupabaseクライアントを使用しているか確認
3. checkAuthStatusでセッション復元が正しく行われているか確認

### タイムゾーン関連の問題と解決策 （v9.17.0で改善）

#### 問題: 日付がずれる、異なるタイムゾーンのデバイスで表示がおかしい

**原因と解決策**:

1. **Calendar.currentの使用を確認**
   - ❌ 問題: `Calendar.current`はiPhoneのタイムゾーン
   - ✅ 解決: `deviceManager.deviceCalendar`を使用

2. **UTC変換の確認**
   - ❌ 問題: データをUTCに変換している
   - ✅ 解決: デバイスのローカル時間のまま保存

3. **デバイス切り替え時の問題**
   - 確認: `DeviceManager.selectedDeviceTimezone`が正しく取得されているか
   - 確認: 各Viewが`@EnvironmentObject`でDeviceManagerを参照しているか

4. **データベースの確認**
   ```sql
   -- デバイスのタイムゾーンが設定されているか確認
   SELECT device_id, timezone FROM devices WHERE device_id = 'your-device-id';
   
   -- タイムゾーンがNULLの場合は更新
   UPDATE devices SET timezone = 'Asia/Tokyo' WHERE device_id = 'your-device-id';
   ```

5. **デバッグ方法**
   ```swift
   // 現在のデバイスタイムゾーンを確認
   print("Device Timezone: \(deviceManager.selectedDeviceTimezone)")
   
   // キャッシュキーを確認（日付が正しいか）
   print("Cache Key: \(makeCacheKey(deviceId: deviceId, date: date))")
   ```

#### 問題: file_pathの日付とグラフ表示の日付が一致しない

**原因**: Vault APIでのfile_path生成時とiOSアプリでの表示時でタイムゾーンが異なる

**解決策**:
1. Vault APIが`recorded_at`のタイムゾーンを保持しているか確認
2. file_pathの日付部分がデバイスのローカル日付になっているか確認
3. iOS側で`SlotTimeUtility.getDateString`にタイムゾーンを渡しているか確認

### ビルドエラー

- **パッケージ依存関係エラー**: 上記の「Xcodeビルドエラーの対処」を参照
- **シミュレータでのビルドエラー**: 実機を選択するか、適切なシミュレータを選択

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

1. **選択中のデバイスIDを確認**
   ```swift
   print("Selected Device ID: \(deviceManager.selectedDeviceID ?? "nil")")
   ```

2. **Supabaseでデータ存在確認**
   ```sql
   -- デバイスの確認
   SELECT * FROM devices WHERE owner_user_id = 'ユーザーID';
   
   -- VIBEデータの確認
   SELECT * FROM vibe_whisper_summary WHERE device_id = 'デバイスID';
   ```

3. **日付フォーマットの確認**
   - 日付は`YYYY-MM-DD`形式で保存される
   - タイムゾーンは考慮されない（日付のみ）

## UI/UX設計ガイドライン

### NavigationViewの適切な使用方法

本アプリケーションでは、iOS標準のUIを維持しつつ、適切なナビゲーション構造を実現するため、以下のルールを遵守します：

#### ✅ 推奨される実装パターン

1. **モーダル（.sheet）内でのNavigationView使用**
   ```swift
   .sheet(isPresented: $showSheet) {
       NavigationView {  // モーダル内で独立したNavigationViewを使用
           ContentView()
               .navigationTitle("タイトル")
               .toolbar {
                   ToolbarItem(placement: .cancellationAction) {
                       Button("キャンセル") { dismiss() }
                   }
               }
       }
   }
   ```
   - モーダルは独立したプレゼンテーションなので、その中でNavigationViewを使用してもネストになりません
   - iOS標準の美しいツールバーとナビゲーションバーが利用できます

2. **NavigationLinkによる画面遷移**
   ```swift
   NavigationLink(destination: DetailView()) {
       Text("詳細画面へ")
   }
   ```
   - 階層的なナビゲーションにはNavigationLinkを使用
   - モーダルではなく、プッシュ遷移が適切な場合に使用

#### ❌ 避けるべき実装パターン

1. **NavigationViewの入れ子（ネスト）**
   ```swift
   // NG: NavigationView内でさらにNavigationViewを含むビューを表示
   NavigationView {
       NavigationLink(destination: NavigationView { ... })
   }
   ```

2. **モーダル呼び出し時のNavigationViewラップ**
   ```swift
   // NG: sheet呼び出し側でNavigationViewでラップ
   .sheet(isPresented: $show) {
       NavigationView {  // 呼び出し側でラップしない
           SomeView()
       }
   }
   ```

#### 実装例：UserInfoViewのアバター選択

正しい実装により、iOS標準の美しいUIを実現：
- アバター選択画面はモーダル（sheet）で表示
- モーダル内で独立したNavigationViewを使用
- 標準的なツールバーでキャンセルボタンを配置

## Git 運用ルール（ブランチベース開発フロー）

このプロジェクトでは、**ブランチベースの開発フロー**を採用しています。  
main ブランチで直接開発せず、以下のルールに従って作業を進めてください。

---

### 🔹 運用ルール概要

1. `main` ブランチは常に安定した状態を保ちます（リリース可能な状態）。
2. 開発作業はすべて **`feature/xxx` ブランチ** で行ってください。
3. 作業が完了したら、GitHub上で Pull Request（PR）を作成し、差分を確認した上で `main` にマージしてください。
4. **1人開発の場合でも、必ずPRを経由して `main` にマージしてください**（レビューは不要、自分で確認＆マージOK）。

---

### 🔧 ブランチ運用の手順

#### 1. `main` を最新化して作業ブランチを作成
```bash
git checkout main
git pull origin main
git checkout -b feature/機能名
```

#### 2. 作業内容をコミット
```bash
git add .
git commit -m "変更内容の説明"
```

#### 3. リモートにプッシュしてPR作成
```bash
git push origin feature/機能名
# GitHub上でPull Requestを作成
```

## 更新履歴

最新バージョン: **v9.29.0** (2025-10-02)

### v9.29.0 (2025-10-02)
- **デバイス管理の大幅簡素化**: 物理デバイスとの紐付けを完全廃止
  - `localDeviceIdentifier`プロパティを削除
  - `isDeviceRegistered`プロパティを削除
  - デバイス連携アラートを削除
  - 録音開始時のチェックを`selectedDeviceID`ベースに変更
- **疎結合設計の実現**: どのiPhoneからでも同じデバイスIDを選択して使用可能
- **バンドルID変更対応**: UserDefaultsに依存しない設計により、バンドルID変更やアプリ再インストールの影響を受けない
- **ポータビリティの向上**: デバイスIDは「データの入れ物」として機能

### v9.28.0 (2025-09-22)
- **Lambda連携の改善**: iPhoneプレフィックスを削除し、純粋なdevice_idを使用
- **リアルタイム処理対応**: すべてのデバイスの音声ファイルが即座に処理されるように改善
- NetworkManager.swiftからiphone_プレフィックス付与処理を削除

詳細な更新履歴は [`CHANGELOG.md`](./CHANGELOG.md) を参照してください。

## 🔒 セキュリティ関連の重要事項

### ✅ 実施済みのセキュリティ対策

1. **HTTPS通信の強制**（2025-08-16完了）
   - すべてのAPI通信がHTTPS経由に移行
   - Info.plistのATS例外設定（`NSAllowsArbitraryLoads`）を削除
   - 中間者攻撃のリスクを排除

2. **UUID正規化**
   - アバターアップロード時にUUIDを小文字に統一
   - S3パスの一貫性を保証

### ⚠️ 未対応のセキュリティリスク（要対応）

#### 🔴 Avatar Uploader APIの認証機能が無効化中

**現在の問題：**
- Avatar Uploader API（`https://api.hey-watch.me/avatar/`）が認証なしでアクセス可能
- 悪意のある第三者が他人のアバターを自由に変更可能
- user_idを知っていれば誰でもアバターを上書きできる

**必要な対応：**
1. Avatar Uploader APIの`app.py`で認証処理を有効化
2. Supabase JWTトークンの検証を実装
3. user_idとトークンの所有者が一致することを確認

**iOS側で実装済みの認証コード：**
```swift
// AWSManager.swift（72-74行目）
if let token = authToken {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}

// UserInfoView.swift（188-189行目）
let authToken = authManager.getAccessToken()  // トークン取得済み
```

**API側で必要な実装：**
詳細は[Avatar Uploader APIのREADME](../projects/watchme/api/avatar-uploader/README.md)を参照

### 📋 本番環境移行前のチェックリスト

- [x] すべてのAPIエンドポイントをHTTPS化
- [x] Info.plistのATS例外設定を削除
- [x] アプリ側で認証トークンを送信
- [ ] **Avatar Uploader APIの認証機能を有効化**（未対応）
- [ ] APIのレート制限を実装（推奨）
- [ ] CloudFront CDNの設定（オプション）

### 🚨 重要な注意

**現在のAvatar Uploader APIは開発・テスト用の設定です。**
本番環境で使用する前に、必ず認証機能を有効化してください。

## ライセンス

プロプライエタリ