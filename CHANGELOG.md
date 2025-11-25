# 更新履歴

> **関連ドキュメント**
> - [README.md](./README.md) - アプリ全体の概要
> - [AUTHENTICATION.md](./docs/AUTHENTICATION.md) - 認証システム詳細
> - [TECHNICAL.md](./docs/TECHNICAL.md) - アーキテクチャ・データベース設計

---

## 2025年11月

### v9.30.0 (2025-11-25)

#### 認証システムの改善と安定化
- **fullScreenCover二重ネスト問題の解消**:
  - `AuthFlowView.swift`でオンボーディングとアカウント選択を統合
  - 1層のfullScreenCoverのみに変更し、モーダルクローズの不安定性を解消
  - OAuth認証後のモーダル自動クローズが確実に動作
  - コミット: `d978be5`

- **エラーメッセージ表示の統一**:
  - `ToastManager.swift`導入により全エラーを統一的に表示
  - 非侵襲的（画面を遮らない）で一貫したUX
  - 認証エラー、デバイス登録エラー等をトーストで表示
  - コミット: `3509361`

- **匿名ユーザーのアップグレードフロー実装**:
  - `UpgradeAccountView.swift`追加：ゲストユーザーがGoogleアカウントに移行可能
  - `UserAccountManager.swift`に`upgradeAnonymousToGoogle()`メソッド追加（L1403-1477）
  - 既存データを保持したままアカウントアップグレードが可能
  - `AccountSettingsView.swift`にプロモーションバナー追加（L29-58）
  - コミット: `1f61fd9`

#### コード品質の改善
- **MainAppViewのリファクタリング**:
  - タブビュー構造の重複を解消（約70行削減、46行追加）
  - `private var mainTabView`で共通化し、保守性向上
  - 認証済み・未認証モードで同じタブ構造を共有
  - タブ追加時の修正箇所を2箇所 → 1箇所に削減
  - コミット: `c8afe2c`

#### ドキュメント整理
- **認証システムドキュメントの分離**:
  - `docs/AUTHENTICATION.md`を新規作成
  - 認証方式、フロー、データベース設計の詳細を集約
  - README.mdを簡潔化し、認証は概要のみに

- **README.mdの大幅簡潔化**:
  - 認証セクションを約150行 → 10行に削減
  - 履歴情報をCHANGELOG.mdに移動
  - 冒頭に関連ドキュメントへのリンクを追加
  - 重複する「関連ドキュメント」セクションを削除

- **引き継ぎドキュメントの削除**:
  - `docs/REMAINING_TASKS.md`を削除（タスク完了のため）

#### データベーススキーマ更新
- **`public.users`テーブル**:
  - `auth_provider`カラム追加（匿名、Google、メール等を区別）
  - マイグレーション: `migrations/20251125000000_add_auth_provider_to_users.sql`
  - スキーマドキュメント更新: `current_schema.sql`

#### 実装ファイル
- 新規: `AuthFlowView.swift`, `UpgradeAccountView.swift`, `ToastManager.swift`, `docs/AUTHENTICATION.md`
- 更新: `UserAccountManager.swift`, `AccountSettingsView.swift`, `ios_watchme_v9App.swift`, `README.md`

---

## 2025年10月

### v9.29.0 (2025-10-19)
- **アカウント削除機能の実装（App Store審査対応）**:
  - App Store Guidelines 5.1.1に準拠したアカウント削除機能を追加
  - `NetworkManager.swift`に`deleteAccount(userId:)`メソッドを実装（655-689行目）
  - `AccountSettingsView.swift`に削除フローを実装（196-229行目）
  - 管理画面API経由でユーザーデータを完全削除（`DELETE https://admin.hey-watch.me/api/users/{user_id}`）
  - 削除対象: `user_devices`, `auth.users`（Supabase Admin API）, `public.users`（CASCADE）
  - パフォーマンス最適化: NetworkManagerを遅延初期化（削除時のみインスタンス化）
  - 実機テスト完了・ビルド検証完了
- **関連ドキュメント**:
  - [ACCOUNT_DELETION.md](./docs/ACCOUNT_DELETION.md) - 実装仕様とPhase 1-B残タスク

## 2025年9月

### v9.28.0 (2025-09-22)
- **Lambda連携の改善**: プレフィックスを削除してクリーンな実装に
  - NetworkManager.swiftから`iphone_`プレフィックス付与処理を削除
  - 純粋なdevice_idをそのまま使用（プレフィックスなし）
  - Lambda関数がすべてのデバイス（iPhone、オブザーバー含む）を一律処理
  - データベースのdevice_idカラムもプレフィックスなしで統一

### v9.27.0 (2025-09-22)
- **リアルタイム音声処理対応**: Lambda関数によるリアルタイム処理のためにS3パス生成を修正
  - NetworkManager.swiftでS3アップロード時のdevice_idに`iphone_`プレフィックスを追加
  - Lambda関数がiPhoneデバイスを自動識別してリアルタイム処理を実行
  - 処理時間を従来の最大1時間から約30秒に短縮
  - データベースのdevice_idは変更せず、既存機能との互換性を維持

### v9.26.0 (2025-09-21)
- **データソースの完全統一**
  - vibe_whisper_summaryテーブルの依存を完全に排除
  - すべての気分データをdashboard_summaryテーブルから取得するように変更
  - RPC関数get_dashboard_dataからvibe_reportフィールドを削除
- **グラフ表示の改善**
  - InteractiveTimelineViewでnullデータを0として扱うように統一
  - グラフライン（黒線・グレー線）とインジケーターの動作を一致
  - データの連続性を保ち、見た目を安定化
- **新機能追加**
  - dashboard_summaryテーブルにburst_eventsとinsightsフィールドを追加
  - バーストイベント（感情の急変点）の表示を新しいデータソースから取得
  - 1日のサマリーインサイトを独立したフィールドから取得

### v9.25.0 (2025-09-18)
- **心理グラフの大幅リニューアル**: 
  - 既存のグラフ表示からdashboardテーブルの時間詳細リスト表示に変更
  - 48スロット（30分間隔）の時間ごとにsummaryとvibe_scoreを表示
  - コンパクトな1行表示で一覧性を向上
- **UI/UX改善**:
  - ログインフォームの入力欄とボタンを標準高さ44ptに統一
  - アプリのメインカラー（AppAccentColor/紫）をログイン関連ボタンに適用
  - コメント入力時のキーボード制御を改善（スクロールや画面タップで自動的に閉じる）
  - 時間リストのスクロール時の誤タップを防止（BorderlessButtonStyleに変更）

## 2025年8月

### v9.24.1 (2025-08-26)
- **音声録音品質の大幅改善**: AudioRecorder.swiftの録音設定を最適化
  - AVAudioSessionモードを`measurement`から`spokenAudio`に変更
  - 録音品質を`medium`から`high`に向上
  - マイクゲインを最大値（1.0）に設定して音量を向上
  - 音声会話に特化した録音パラメータでAI分析精度を向上
- **ユーザビリティ向上**: より明瞭な音声データでより正確な感情・行動分析を実現

### v9.23.0 (2025-08-23)
- **ダッシュボードUI改善**:
  - **日付表示の特別化**: 本日は「今日」と大きく表示、実際の日付を小さく併記
  - **過去の日付表示改善**: 年を小さく、月日を大きく、曜日を小さく階層的に表示
  - **日付セクション背景**: 紫色（AppAccentColor）背景に白文字で視認性向上
  - **カードデザイン簡素化**: ドロップシャドウを削除してフラットなデザインに
- **カスタムカレンダー機能**:
  - 月間の気分データを絵文字で一覧表示
  - 日付選択機能を維持しながら気分の傾向を視覚的に把握
  - 既存の絵文字ロジック（DailyVibeReport）を共通化して使用
  - パフォーマンス最適化: 月単位でデータを一括取得

### v9.22.0 (2025-08-23)
- **通知機能の実装**: 3種類の通知（グローバル、パーソナル、イベント）を統合管理
  - グローバル通知: 全ユーザー向けのシステム通知
  - パーソナル通知: 特定ユーザー向けの個別通知
  - イベント通知: システムイベント駆動型の通知
- **既読管理システム**: 通知タイプごとに最適化された既読管理
  - グローバル通知はnotification_readsテーブルで管理
  - パーソナル/イベント通知はis_readフィールドで管理
- **未読バッジ機能**: ヘッダーに未読数を表示（最大99）
- **統一された通知UI**: 全通知を1画面で時系列表示
- **プルリフレッシュ対応**: 下にスワイプで通知を再取得

### v9.21.0 (2025-08-18)
- **アバタートリミング機能の改善**: Mantisライブラリ導入による高機能化
  - 円形トリミングによるアバター最適化
  - 画像の向き（EXIF）自動補正
  - プロフェッショナルなトリミングUI
  - カメラロールからの選択時の位置ずれバグを修正
- **安定性向上**: 実績のあるライブラリによる堅牢な実装

### v9.20.0 (2025-08-16)
- **アバター機能の完全実装**: ユーザーと観測対象のアバター管理機能を実装
  - Avatar Uploader API経由でのセキュアなアップロード
  - S3（watchme-avatars）への画像保存と表示
  - 画像の選択・トリミング・アップロードの完全なフロー
- **セキュリティ強化**: AWS認証情報をクライアントから完全に排除
- **API統合**: Avatar Uploader API（http://3.24.16.82:8014）との連携
- **Supabase認証トークン**: アバターアップロード時の認証実装

### v9.19.0 (2025-08-15)
- **ダッシュボードスワイプ機能**: TabViewによる日付切り替えを実装
- **モーダル詳細表示**: 各グラフをシート表示に変更（ドリルダウン構造）
- **パフォーマンス改善**: TabViewのネストを解消し、滑らかな動作を実現
- **UX改善**: 詳細画面がモーダルで表示され、スワイプダウンで簡単に戻れる

### 2025年8月14日
- **v9.18.0 - ダッシュボード日付変更バグの根本的修正**
  - **問題の根本原因**
    - 過剰な設計（DashboardViewModel、キャッシュ、fetchID、DatePagingView）が原因
    - 日付変更という基本的な機能に複雑すぎる実装を使用していた
    
  - **解決策：SwiftUIの標準機能への回帰**
    - `.task(id:)`モディファイアのみで日付変更を処理
    - ViewModelパターンを廃止し、シンプルな`@State`管理に変更
    - 複雑なキャッシュシステムとプリロード機能を削除
    - DatePagingViewのForEachループを削除
    
  - **削除したファイル**
    - DashboardViewModel.swift（複雑なViewModel）
    - DatePagingView.swift（複雑なページング機構）
    - DashboardView.swift、NewHomeView.swift（旧ダッシュボード）
    - ContentViewState.swift、ChangeHandlerModifier.swift等のヘルパー
    
  - **新しいアーキテクチャ**
    - SimpleDashboardView.swift：`.task(id: selectedDate)`でデータ取得
    - 各グラフビューが独立してデータを取得
    - 日付が変更されると自動的に新しいデータを取得
    - SwiftUIの標準的な動作に依存
    
  - **成果**
    - 日付変更時のデータ表示バグを完全に解消
    - コードベースを大幅に簡素化（数百行のコード削除）
    - 保守性と可読性が大幅に向上
    - 「過剰な設計」の典型例からの脱却

### 2025年8月11日
- **v9.17.3 - platform_identifierとplatform_typeカラムの完全削除**
  - **データベース構造の簡素化**
    - devicesテーブルからplatform_identifierカラムを削除
    - devicesテーブルからplatform_typeカラムを削除
    - 外部デバイス登録時の制約を排除
    - QRコードデバイス追加のエラー「The data couldn't be read because it is missing」を解決
    
  - **iOSアプリケーションの簡素化**
    - Device構造体からplatform_identifier/platform_typeフィールドを削除
    - DeviceInsert構造体からplatform_identifier/platform_typeフィールドを削除
    - DeviceInfo構造体からplatformIdentifier/platformTypeフィールドを削除
    - getPlatformIdentifier()メソッドを削除
    - platformIdentifierKey定数を削除
    - デバイス登録処理の大幅な簡略化
    - 45行のコード削除によるメンテナンス性向上
    
  - **外部デバイス対応の改善**
    - 外部デバイス（観測専用デバイス）の登録が大幅に簡潔に
    - platform情報不要でデバイス登録可能
    - QRコードによるデバイス追加の信頼性向上
    
  - **データベース変更SQL**
    ```sql
    ALTER TABLE devices 
    DROP COLUMN IF EXISTS platform_identifier,
    DROP COLUMN IF EXISTS platform_type;
    ```
    
  - **影響**
    - 既存機能への影響なし（未使用フィールドの削除）
    - Vault APIとの連携に影響なし
    - 録音データ処理フローに影響なし
    - コードの保守性とクリーンさが大幅に向上

### 2025年8月4日
- **v9.17.0 - デバイスタイムゾーン中心の設計を全面実装**
  - **ライフログツールとしての設計思想を明確化**
    - 観測対象（デバイスを装着している人）の生活リズムを正確に記録
    - デバイスのタイムゾーン = 観測対象が生活している場所のタイムゾーン
    - アカウント所有者の位置は無関係（観測データを閲覧するだけ）
    - 旅行などの一時的な移動ではタイムゾーンを変更しない（一貫性のため）
    
  - **file_pathの重要性と構造化計画**
    - file_pathが信頼できる唯一の時間情報源であることを文書化
    - Whisper API、ChatGPT処理でfile_pathから日付・時間を抽出
    - recorded_atカラムの廃止計画を策定（グラフ生成で未使用のため）
    - 将来的なaudio_filesテーブル構造化（local_date、time_slot）を計画
    
  - **UTC変換の完全廃止**
    - SlotTimeUtilityからUTC変換を削除
    - SupabaseDataManagerからUTC変換を削除
    - データはデバイスのローカル時間で保存・処理・表示
    
  - **Calendar.currentの使用廃止**
    - DatePagingView、DateNavigationViewをデバイスCalendar使用に変更
    - 「今日」の判定もデバイスのタイムゾーンで実行
    - すべての日付計算をdeviceManager.deviceCalendarで統一
    
  - **DeviceManagerの拡張**
    - `selectedDeviceTimezone`プロパティ追加（選択デバイスのタイムゾーン取得）
    - `deviceCalendar`プロパティ追加（デバイスタイムゾーンのCalendar）
    - `getTimezone(for:)`メソッド追加（特定デバイスのタイムゾーン取得）
    
  - **データ取得時のタイムゾーン対応**
    - DashboardViewModelのキャッシュキー生成でデバイスタイムゾーン使用
    - SupabaseDataManagerの`fetchAllReports`にタイムゾーンパラメータ追加
    - デバイス切り替え時に自動的にタイムゾーンが適用される
    
  - **録音機能のタイムゾーン対応**
    - AudioRecorderがデバイスのタイムゾーンでファイルパス生成
    - RecordingViewの日時表示もデバイスタイムゾーンに対応
    
  - **データベース構造の更新**
    - devicesテーブルにtimezoneカラムを追加（IANAタイムゾーン識別子）
    - デバイス登録時にTimeZone.current.identifierを保存
    
  - **実装の技術的詳細**
    - タイムゾーンの明示的な管理（暗黙的な使用を避ける）
    - デバイス切り替え時のタイムゾーン伝搬を確実に実施
    - 将来の複数デバイス統合表示への対応基盤を整備

### 2025年8月1日
- **v9.16.1 - Avatar Uploader API連携実装（未解決の問題あり）**
  - **実装内容**
    - Avatar Uploader API（http://3.24.16.82:8014）との連携実装
    - AWSManager.swiftをAPI連携用に全面改修
    - multipart/form-dataでの画像アップロード実装
    - S3 URLからの画像読み込み処理
    - Configuration.swiftで開発/本番環境の切り替え設定
    
  - **⚠️ 未解決の問題 ⚠️**
    1. **画像選択後に真っ白になる問題**
       - PhotosPickerまたはカメラで画像を選択後、ImageCropperViewで画像が表示されず真っ白になる
       - UIGraphicsImageRendererを使用した画像処理に変更したが改善せず
       - デバッグログは追加済みだが、根本原因は未特定
       
    2. **アバター画像が表示されない問題**
       - APIへのアップロードは成功（ステータス200）
       - S3にファイルは保存される（テストで確認済み）
       - AsyncImageで画像を読み込もうとすると301リダイレクトが発生
       - S3バケットがap-southeast-2にあるが、URLがus-east-1形式のため
    
  - **技術的な詳細**
    - **UUID形式のID必須**: user_idとsubject_idは必ずUUID形式が必要
    - **S3リダイレクト問題**: us-east-1 → ap-southeast-2へのリダイレクト
    - **CORS/バケットポリシー**: S3側の設定確認が必要な可能性
    
  - **次のステップ**
    1. ImageCropperViewの画像処理ロジックのデバッグ
       - 画像のサイズやスケール計算の問題を調査
       - SwiftUIのレンダリングコンテキストの問題を確認
    2. S3アクセスの改善
       - リダイレクトを適切に処理する方法の検討
       - バケットポリシーやCORS設定の確認
       - CloudFront経由でのアクセスの検討
    3. エラーハンドリングの強化
       - より詳細なエラーログの追加
       - ユーザーへのフィードバック改善

### 2025年7月31日
- **v9.16.0 - アバター機能の実装（ペンディング）**
  - **⚠️ 現在ペンディング状態 ⚠️**
    - アバターアップロード専用APIの実装待ち
    - APIエンドポイントが提供され次第、実装を更新予定
    - 現在はローカルファイルシステムに保存する暫定実装
    
  - **実装した機能**
    - UserアバターとSubjectアバターの画像選択・編集機能
    - 共通のアバター選択コンポーネント（AvatarPickerView）
    - PHPickerViewControllerを使用した写真ライブラリからの選択
    - カメラ撮影機能（UIImagePickerController）
    - 画像トリミング機能（300x300の正方形）
    
  - **暫定実装の詳細**
    - 画像はDocumentsディレクトリに保存
    - パス形式: `Documents/{type}/{id}/avatar.jpg`
    - typeは "users" または "subjects"
    - JPEG形式、品質80%で保存
    
  - **API実装後の想定仕様**
    - エンドポイント: `POST /api/avatar/upload`
    - リクエスト: multipart/form-data
      - file: 画像ファイル
      - type: "users" or "subjects"
      - id: ユーザーIDまたはサブジェクトID
    - レスポンス: `{ url: "https://..." }`
    - アップロード後はS3のURLを使用してアバターを表示
    
  - **実装ファイル**
    - `AWSManager.swift`: アバターアップロード管理（ペンディング実装）
    - `AvatarPickerView.swift`: 共通の画像選択・編集コンポーネント
    - `ContentView.swift`: UserアバターのUI実装
    - `SubjectRegistrationView.swift`: Subjectアバターの実装
    - `DashboardView.swift`: Subjectアバター表示の更新

- **v9.15.0 - QRコードによるデバイス追加機能の実装**
  - **QRコードスキャン機能**
    - デバイス選択画面に「デバイスを追加」ボタンを追加
    - カメラを使用したQRコードのリアルタイムスキャン機能
    - QRコード内容はシンプルにdevice_idのみ（UUID形式のテキスト）
    - AVFoundationを活用したカメラベースのスキャナーを実装
    - カメラ使用許可（NSCameraUsageDescription）をInfo.plistに設定
    
  - **デバイス追加処理の安全性**
    - UUIDフォーマットの妥当性検証
    - データベース内のデバイス存在確認
    - 既に追加済みデバイスの重複チェック
    - user_devicesテーブルへの安全な追加処理
    
  - **ユーザーフィードバック機能**
    - 成功時：「device_id: xxxxx... が閲覧可能になりました！」ポップアップ
    - 失敗時：エラー内容別の詳細メッセージ表示
    - 無効なQRコード、既に追加済み、デバイス未登録などのケース別対応
    
  - **権限管理の改善**
    - デフォルト権限を「viewer」から「owner」に変更
    - QRコードで追加したデバイスは即座にフル機能で利用可能
    
  - **実装ファイル**
    - `QRCodeScannerView.swift`: カメラベースのQRスキャナー
    - `DeviceSelectionView.swift`: デバイス選択UIと追加機能
    - `DeviceManager.swift`: QRコードデバイス追加ロジック
    - `Info.plist`: カメラ使用許可の設定

### 2025年7月30日
- **v9.14.0 - 観測対象管理をsubjectsテーブルに移行**
  - **データベース構造の変更**
    - 新規`subjects`テーブルを追加（観測対象の情報を独立して管理）
    - `devices`テーブルに`subject_id`フィールドを追加
    - `device_metadata`テーブルの参照を`subjects`テーブルに変更（device_metadataは今後削除予定）
    
  - **観測対象管理の改善**
    - 観測対象（subjects）をデバイスから独立して管理
    - 1つのデバイスに1つの観測対象を紐付け
    - 複数のデバイスが同じ観測対象を参照可能（デバイス買い替え時などに対応）
    
  - **アプリケーションの変更**
    - `DeviceMetadata`モデルを`Subject`モデルに置き換え
    - `SupabaseDataManager`の`fetchDeviceMetadata`を`fetchSubjectForDevice`に変更
    - デバイスに観測対象が未登録の場合の表示を実装
    
  - **今後の拡張予定**
    - 観測対象の登録・編集機能の追加
    - 観測対象の切り替え機能の実装

### 2025年7月30日
- **v9.13.1 - デバイス未連携時の録音制御機能を実装**
  - **録音開始時のデバイス連携チェック機能**
    - デバイス未連携の状態で録音開始ボタンを押すと、デバイス連携を促すダイアログを表示
    - 「デバイスが連携されていないため録音できません。このデバイスを連携しますか？」というメッセージで確認
    - 「はい」を選択すると、デバイス連携処理を実行し、成功後に自動的に録音を開始
    - 「キャンセル」を選択すると、録音は開始されない
    
  - **UI/UXの改善点**
    - デバイス連携中は画面全体にオーバーレイを表示し、進行状況を明示
    - 連携成功後は自動的に録音が開始されるため、ユーザーの手間を削減
    - エラー時は適切なエラーメッセージを表示
    
  - **技術的な実装**
    - RecordingViewに`showDeviceLinkAlert`と`isLinkingDevice`の状態管理を追加
    - `linkDeviceAndStartRecording()`メソッドでデバイス連携と録音開始を連続実行
    - デバイスIDなしでアップロードされる無効な録音データを防止
    
  - **グラフ表示のエラーメッセージ共通化**
    - `GraphEmptyStateView`コンポーネントを作成し、エラー表示ロジックを一元化
    - デバイス未連携時：「デバイスが連携されていません」（オレンジ色のアイコン）
    - データなし時：「指定した日付のデータがありません」（グレー色のアイコン）
    - 全グラフビュー（心理、行動、感情、ダッシュボード）で統一された表示

- **v9.13.0 - ログイン時のデバイス自動登録機能を削除**
  - **デバイス登録の仕様変更**
    - ログイン時の自動デバイス登録を完全に削除
    - ユーザーが明示的に操作した場合のみデバイス登録を行うように変更
    - 録音ボタン押下時にデバイス未登録の場合は登録を促すUIを実装（v9.13.1で実装済み）
    
  - **コード変更の詳細**
    - `SupabaseAuthManager`から`checkAndRegisterDevice`の呼び出しを削除
    - 代わりに`fetchUserDevices`のみを呼び出し、既存のデバイス一覧を取得
    - `DeviceManager.checkAndRegisterDevice`関数を完全に削除
    - `DeviceManager.registerDevice`のuserIdパラメータを必須に変更
    
  - **影響と注意点**
    - 新規ユーザーはログイン後、デバイスが未登録の状態となる
    - デバイス未登録の場合、録音のアップロードは失敗する（既存の仕様通り）
    - 既存ユーザーには影響なし（すでに登録済みのデバイスはそのまま使用可能）
    
  - **UI改善**
    - ユーザー情報画面にデバイス連携状態を表示
    - デバイス未連携時は「デバイスが連携されていません」と表示
    - 「このデバイスを連携」ボタンで簡単に連携可能
    - ホーム画面左上にデバイス連携状態を表示（「デバイス連携: なし」）

### 2025年7月29日
- **v9.12.1 - 手動API呼び出しからSDK標準メソッド化による認証情報不整合問題の根本解決**
  - **SupabaseAuthManagerの完全SDK化**
    - signUpメソッドを`supabase.auth.signUp()`に変更
    - signOutメソッドを`supabase.auth.signOut()`に変更
    - fetchUserInfoメソッドを`supabase.auth.session.user`に変更
    - resendConfirmationEmailメソッドを`supabase.auth.resend()`に変更
    - fetchUserProfileメソッドを`supabase.from("users").select()`に変更
    - refreshTokenメソッドを削除（SDKが自動管理）
    
  - **SupabaseDataManagerの完全SDK化**
    - fetchDailyReportメソッドを`supabase.from("vibe_whisper_summary").select()`に変更
    - fetchBehaviorReportメソッドを`supabase.from("behavior_summary").select()`に変更
    - fetchEmotionReportメソッドを`supabase.from("emotion_opensmile_summary").select()`に変更
    - fetchDeviceMetadataメソッドを`supabase.from("device_metadata").select()`に変更（v9.14.0で`fetchSubjectForDevice`に変更）
    - fetchWeeklyReportsメソッドを`supabase.from("vibe_whisper_summary").select()`に変更
    
  - **認証情報の不整合問題を根本解決**
    - 手動のURLSession API呼び出しを完全に排除
    - SDKが自動的に認証トークンを管理し、RLSポリシーを正しく通過
    - PostgrestErrorの詳細表示機能を追加してデバッグを改善
    - トークンの自動リフレッシュによる堅牢なセッション管理

- **v9.12.0 - user_devicesテーブル対応と認証フロー修正**
  - **データベース構造の変更**
    - `user_devices`中間テーブルに対応
    - ユーザーとデバイスの多対多関係を実現
    - owner/viewerロールによる権限管理
    
  - **認証フローの根本的修正**
    - SupabaseAuthManagerの`signIn`を標準SDKメソッドに変更
    - 手動のAPI呼び出しを廃止し、`supabase.auth.signIn()`を使用
    - 認証トークンの自動管理を実現
    
  - **認証状態復元の実装**
    - `checkAuthStatus`で`supabase.auth.setSession()`を呼び出し
    - アプリ再起動時も認証状態を正しく維持
    
  - **DeviceManagerの改修**
    - 独自のSupabaseクライアント初期化を削除
    - グローバルな認証済みクライアントを使用
    - `fetchUserDevices`をuser_devices経由に変更
    
  - **トラブルシューティング情報追加**
    - RLSポリシーの重要性を強調
    - 認証関連の問題解決方法を詳細化

### 2025年7月27日（追加修正）
- **v9.11.1 - 日付選択機能の最終調整とコード整理**
  - **HomeView.swiftの修正**
    - 不要な`showUserInfoSheet`への参照を削除
    - 個別のデータフェッチロジックを削除し、ContentViewで管理されるデータフローに統一
    - toolbarからユーザーアイコンボタンを削除（ContentViewのヘッダーに集約）
    
  - **ディレクトリ構造の正確化**
    - README.mdのディレクトリ構造を実際のファイル配置に合わせて修正
    - ManagersディレクトリとViewsディレクトリは存在せず、全ファイルがルート直下に配置
    - ContentView.swiftの説明を「日付選択とTabViewを使用したグローバルナビゲーション」に更新
    
  - **DailyVibeReport.swiftの確認**
    - scoreColorとemotionIconメソッドが既に実装済みであることを確認
    - 各グラフビューがエクステンションメソッドを正しく使用していることを確認
    
  - **グラフビューの確認**
    - BehaviorGraphViewとEmotionGraphViewは既に日付ナビゲーションUIが削除済み
    - dataManagerから直接データを参照する実装になっていることを確認

### 2025年7月27日
- **v9.11.0 - データフロー階層構造への大規模リファクタリング**
  - **「デバイス → 日付 → グラフ」階層構造の実装**
    - ライフログツールとして最適なUI階層を実現
    - デバイスと日付の選択を最上位（ContentView）に集約
    - すべてのグラフが同一のデバイス・日付のデータを表示
    
  - **統合データ管理の実現**
    - `ContentView`に`selectedDate`の状態管理を一元化
    - 固定ヘッダー（ユーザーアイコンとアプリタイトル）の実装
    - 日付ナビゲーションをTabViewの上に配置し、全グラフで共有
    - デバイスまたは日付変更時に、すべてのレポートを自動的に再取得
    
  - **SupabaseDataManagerの拡張**
    - `dailyBehaviorReport`と`dailyEmotionReport`の`@Published`プロパティを追加
    - `fetchAllReports`メソッドで3つのレポートを並行取得
    - Swift 6対応: TaskブロックとMainActor.runに`[weak self]`を追加
    
  - **各グラフビューの簡素化**
    - HomeView、BehaviorGraphView、EmotionGraphViewから日付ナビゲーションUIを削除
    - 個別のデータフェッチロジックを削除
    - SupabaseDataManagerの`@Published`プロパティを直接参照する設計に変更
    
  - **コード品質の向上**
    - ContentViewのbodyを簡素化（AppHeaderView、DateNavigationViewに分割）
    - `scoreColor`と`emotionIcon`をDailyVibeReportのエクステンションに移動
    - 冗長なコードの削除とエラー処理の改善

- **v9.10.0 - 行動グラフと感情グラフの実装**
  - **行動グラフ (Behavior Graph) の実装**
    - behavior_summaryテーブルからのデータ取得機能
    - 1日の行動ランキング表示（上位5件）
    - 48個の時間ブロック（30分単位）での行動可視化
    - 時間帯別の色分け表示（深夜・朝・昼・夕方・夜）
    - タップで各時間帯の詳細表示
  
  - **感情グラフ (Emotion Graph) の実装**
    - emotion_opensmile_summaryテーブルからのデータ取得機能
    - 8つの感情の1日の合計値をランキング表示
    - 48時間帯の感情推移を折れ線グラフで表示
    - Charts frameworkを使用した美しいグラフ描画
    - 各感情の表示/非表示切り替え機能
    - 凡例の表示/非表示機能
  
  - **データモデルの追加**
    - BehaviorReport.swift: 行動データモデル
    - EmotionReport.swift: 感情データモデル（8感情対応）
  
  - **SupabaseDataManagerの拡張**
    - fetchBehaviorReport()メソッドの追加
    - fetchEmotionReport()メソッドの追加
    - 既存の認証・デバイス管理機能との統合

### 2025年7月25日
- **v9.9.0 - データ管理の一元化リファクタリング**
  - **Single Source of Truthの実現**
    - `SupabaseDataManager`を`@EnvironmentObject`パターンで一元管理
    - `ios_watchme_v9App.swift`でアプリレベルでの初期化を実装
    - `HomeView`の`@StateObject`を`@EnvironmentObject`に移行
  
  - **アーキテクチャの改善**
    - データの一貫性保証：全ビューが同じデータソースを参照
    - 効率性向上：不要なAPIコールとインスタンス生成を削減
    - スケーラビリティ：新しいグラフビューでも同じデータソースを利用可能
  
  - **今後の拡張に向けた基盤整備**
    - 行動グラフ・感情グラフ実装時のデータ共有基盤を確立
    - ビュー間での状態同期の自動化を実現

- **v9.8.0 - UI/UXの大幅改善と疎結合アーキテクチャの導入**
  - **TabViewベースのグローバルナビゲーション導入**
    - 「心理グラフ」「行動グラフ」「感情グラフ」「録音」の4タブ構成
    - 各機能への直感的なアクセスを実現
  
  - **疎結合アーキテクチャへのリファクタリング**
    - ContentViewから機能を分離
    - RecordingView: 録音機能を独立したViewに
    - HomeView: 心理グラフ表示専用Viewに
    - BehaviorGraphView/EmotionGraphView: 将来機能用プレースホルダー
  
  - **心理グラフ（Vibe Graph）のUI完全リニューアル**
    - タブ選択時に即座にレポートを表示
    - 日付ナビゲーション（前日/次日）を追加
    - 平均スコアの大きな表示と視覚的な感情アイコン
    - 感情の時間分布をプログレスバーで表現
    - 時間帯別グラフを簡易バーチャートで実装
  
  - **不要な機能の削除**
    - サーバー接続テストボタンを削除
    - 「開発・テスト用機能」フッターを削除
    - 接続ステータス表示を削除

### 2025年7月24日
- **v9.7.0 - アップロード安定化とUI改善**
  - **ストリーミングアップロード方式への移行**
    - NetworkManager.swiftの`uploadRecording`メソッドを全面改修
    - 従来の`Data(contentsOf:)`による一括メモリ読み込みを廃止し、メモリ不足によるアップロード失敗を根本解決
    - 一時ファイル戦略の採用：
      - multipart/form-dataリクエストボディを一時ファイルとして構築
      - FileHandleを使用した効率的なファイル操作
      - 64KB単位のチャンクでストリーミングコピー
    - URLSessionUploadTaskによるOSレベルの最適化：
      - `dataTask`から`uploadTask(with:fromFile:)`に変更
      - バックグラウンドでの安定した転送を実現
    - 確実なリソース管理：
      - deferブロックによる一時ファイルの自動削除
      - エラー時も適切なクリーンアップを保証
    - 結果：大容量ファイルでも安定したアップロードが可能に
  
  - **UI簡素化**
    - RecordingRowViewから個別アップロードボタンを削除
    - 一括アップロード機能に統一してユーザー体験を向上
    - 不要なnetworkManagerプロパティを削除しコードを整理

- **v9.6.0 - スロット切り替え録音の安定化**
  - **performSlotSwitch()の問題解決**
    - Thread.sleepとasyncAfterを除去してメインスレッドブロッキングを解消
    - AVAudioRecorderDelegateを活用した堅牢な非同期処理を実装
    - ファイル保存完了を確実に待ってから次の処理を実行
  - **録音ファイル保存の問題修正**
    - cleanup()タイミングの最適化でcurrentSlotStartTimeが消去される問題を解決
    - 責務の分離によりhandleRecordingCompletion()とスロット切り替え処理を分離
  - **スロット名計算の修正**
    - getCurrentSlot()の代わりにgetNextSlotStartTime()を使用
    - スロット境界での正確な時刻計算により同一ファイル名の上書きを防止
    - 30分をまたぐ録音で複数ファイルが正常に保存されることを確認
  - **デバッグ機能強化**
    - スロット切り替えプロセスの詳細ログを追加
    - pendingSlotSwitchとcurrentSlotStartTimeの状態追跡
    - 同一ファイル名検出時の警告メッセージ

- **コードクリーンアップ**
  - UploadManager.swiftの削除（未使用の古いコード）
  - ContentView.swiftのコメントアウトされた古いコードの削除
  - AudioRecorder.swiftのpendingRecordings冗長プロパティの削除
  - アップロード処理をNetworkManagerに一元化

### 2025年7月19日
- **タイムゾーン処理の改善**
  - `ISO8601DateFormatter`に明示的な`timeZone`設定を追加
  - ローカルタイムゾーンでのタイムスタンプ送信を実装
  - Vault APIとの連携でタイムゾーン情報を保持

### 2025年7月12日
- **v9.5.0 - アップロードシステム安定化リファクタリング**
  - UploadManagerキューシステムの無効化
  - 逐次アップロード機能の実装
  - 完了ハンドラ対応

### 2025年7月9日
- **v9.4.1 - ファイル保存構造変更**
  - ローカルファイル保存構造の階層化
  - アップロードパスにrawディレクトリ追加
