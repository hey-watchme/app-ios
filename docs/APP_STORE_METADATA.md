# App Store Connect メタデータ準備ガイド

このドキュメントは、App Store Connectで入力するメタデータの準備資料です。

---

## 📝 アプリ説明文（App Description）

### 日本語版（4,000文字以内）

```
WatchMe - AI音声分析による心理・感情モニタリング

【概要】
WatchMeは、音声録音とAI分析によって心理状態・感情・行動パターンを可視化するアプリです。録音した音声データをクラウドで分析し、日別のダッシュボードであなたの心理状態をグラフで確認できます。

【主な機能】
・手動での音声録音
・AI による感情分析（OpenAI API使用）
・日別のダッシュボード表示（心理グラフ、行動グラフ、感情グラフ）
・複数デバイスの管理（1ユーザーが複数の観測対象を管理可能）
・リアルタイム通知（分析完了時に自動通知）
・コメント機能（日別の観察記録を投稿）

【こんな方におすすめ】
・自分の心理状態を客観的に把握したい方
・ストレスや感情の変化を記録したい方
・行動パターンを分析して生活改善したい方
・家族やペットの状態を観察したい方

【利用シーン】
・デイリーレポート：1日の終わりに音声を録音して、その日の心理状態を振り返る
・週次レビュー：週単位でグラフを確認し、ストレスの傾向を把握
・複数対象の管理：家族やペットなど、複数の観測対象を一元管理

【セキュリティとプライバシー】
・すべての音声データは暗号化されてクラウドに保存されます
・データはユーザー本人のみがアクセス可能です
・第三者への提供は一切行いません

【サブスクリプションについて】
現在、基本機能は無料でご利用いただけます。将来的にプレミアム機能（より詳細な分析レポート、長期データ保存など）を提供予定です。

【必要な権限】
・マイク：音声録音のため
・カメラ：QRコードスキャン、アバター写真撮影のため
・フォトライブラリ：アバター画像選択のため
・ネットワーク：AI分析のため
```

---

### 英語版（4,000文字以内）

```
WatchMe - AI-Powered Audio Analysis for Psychological & Emotional Monitoring

【Overview】
WatchMe is an app that visualizes your psychological state, emotions, and behavioral patterns through audio recording and AI analysis. Record audio sessions, analyze them in the cloud, and view your mental state on daily dashboards with graphs.

【Key Features】
・Manual audio recording
・AI-powered emotion analysis (using OpenAI API)
・Daily dashboard with psychological, behavioral, and emotional graphs
・Multi-device management (manage multiple observation targets per user)
・Real-time notifications (automatic alerts when analysis is complete)
・Comment feature (post daily observation notes)

【Perfect for】
・Individuals who want to objectively understand their psychological state
・People who want to track stress and emotional changes
・Users who want to analyze behavioral patterns for lifestyle improvement
・Those who want to monitor family members or pets

【Use Cases】
・Daily Reports: Record audio at the end of the day to review your psychological state
・Weekly Reviews: Check graphs weekly to identify stress trends
・Multiple Target Management: Centrally manage multiple observation targets like family or pets

【Security & Privacy】
・All audio data is encrypted and stored in the cloud
・Data is accessible only by the user
・No data is shared with third parties

【Subscription】
Basic features are currently free. Premium features (detailed analysis reports, long-term data storage, etc.) are planned for the future.

【Required Permissions】
・Microphone: For audio recording
・Camera: For QR code scanning and avatar photo capture
・Photo Library: For avatar image selection
・Network: For AI analysis
```

---

## 🖼️ スクリーンショット撮影ガイド

### 必要なサイズ（2024年時点）

| デバイス | 解像度 | 必要枚数 |
|---------|--------|---------|
| iPhone 6.7" (Pro Max) | 1290 x 2796 | 3-10枚 |
| iPhone 6.5" (Xs Max) | 1242 x 2688 | 3-10枚 |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | 3-10枚 |

### 推奨スクリーンショット構成（6枚）

1. **ダッシュボード画面** - メインの心理グラフ表示
2. **感情グラフ画面** - 感情分析の詳細表示
3. **行動グラフ画面** - 行動パターンの詳細表示
4. **録音画面** - 録音機能のUI
5. **デバイス管理画面** - 複数デバイスの一覧
6. **マイページ画面** - ユーザー情報・設定

### 撮影方法

1. Xcodeでシミュレーターを起動
2. デモモード（サンプルデバイス）でアプリを表示
3. `Cmd + S` でスクリーンショットを保存
4. 各画面を撮影

---

## 🔗 必要なURL（✅ 準備完了）

### 1. プライバシーポリシーURL（必須）
```
https://hey-watch.me/privacy
```
**準備状況**: ✅ 公開済み

### 2. 利用規約URL（必須）
```
https://hey-watch.me/terms
```
**準備状況**: ✅ 公開済み

### 3. サポートURL（必須）
```
https://hey-watch.me/
```
**準備状況**: ✅ 公開済み（トップページ）

### 4. マーケティングURL（任意）
```
https://hey-watch.me/
```
**準備状況**: ✅ 公開済み

**注意**: アプリ内のPrivacyPolicyView.swiftとTermsOfServiceView.swiftの内容は、外部Webサイト（https://hey-watch.me/）でも公開されています。

---

## 📋 App Store Connect 入力項目一覧

### アプリ情報（App Information）

| 項目 | 内容 |
|------|------|
| **アプリ名** | WatchMe |
| **サブタイトル** | AI音声分析による心理モニタリング |
| **プライマリカテゴリ** | ヘルスケア/フィットネス |
| **セカンダリカテゴリ** | ライフスタイル（任意） |
| **プライバシーポリシーURL** | https://hey-watch.me/privacy |
| **利用規約URL** | https://hey-watch.me/terms |

### バージョン情報（Version Information）

| 項目 | 内容 |
|------|------|
| **バージョン番号** | 1.0 |
| **著作権** | © 2025 WatchMe Team |
| **サポートURL** | https://hey-watch.me/ |
| **マーケティングURL** | https://hey-watch.me/（任意） |

### App Review情報（App Review Information）

| 項目 | 内容 |
|------|------|
| **連絡先情報** | 審査員が問題発生時に連絡できるメールアドレス・電話番号 |
| **デモアカウント** | 不要（デモモードで確認可能） |
| **メモ** | 下記参照 |

**審査員向けメモ（英語）**:
```
This app allows users to manually record audio sessions for emotional and behavioral analysis.
Background recording is NOT implemented.

To test the app:
1. Launch the app (no login required to view demo data)
2. Demo mode is automatically enabled with sample device data
3. You can view dashboards, graphs, and analysis results without recording

For testing recording feature:
1. Sign up with a test email (no verification required)
2. Tap the microphone icon to start/stop manual recording
3. Recording is foreground-only (not background)

Audio data is uploaded to our server for AI-based analysis using OpenAI API.
```

---

## 🎨 アプリアイコン

**現在のアイコン**: `ios_watchme_v9/Assets.xcassets/AppIcon.appiconset/`

**要件**:
- 1024x1024 PNG
- アルファチャネルなし
- 角丸なし（正方形）

**確認方法**:
```bash
ls ios_watchme_v9/Assets.xcassets/AppIcon.appiconset/
```

---

## 📱 年齢レーティング（Age Rating）

推奨設定：

| 項目 | 設定 |
|------|------|
| **暴力表現** | なし |
| **性的コンテンツ** | なし |
| **賭博** | なし |
| **医療/治療情報** | あり（心理分析を扱うため） |

**推奨レーティング**: 12+ または 17+（医療情報を扱うため）

---

## 🚀 次のステップ

1. **外部URL準備**
   - プライバシーポリシーURLを用意
   - 利用規約URLを用意
   - サポートURLを用意

2. **スクリーンショット撮影**
   - iPhone 6.7"サイズで6枚撮影

3. **App Store Connectにログイン**
   - https://appstoreconnect.apple.com
   - 新規アプリを作成
   - このドキュメントの内容を入力

4. **アプリバイナリのアップロード**
   - Xcodeから Archive → Upload to App Store
   - TestFlight配信またはApp Store審査申請

---

## 📞 サポート連絡先

審査中に問題が発生した場合の連絡先を用意してください：

- **メールアドレス**: support@your-domain.com
- **電話番号**: +81-XX-XXXX-XXXX（任意）

---

## 🔍 審査で確認される可能性のあるポイント

1. **プライバシーマニフェスト** → ✅ 対応済み（PrivacyInfo.xcprivacy）
2. **バックグラウンド録音の説明** → ✅ 対応済み（実装なし）
3. **外部URL** → ⚠️ ユーザーが用意必要
4. **スクリーンショット** → ⚠️ ユーザーが撮影必要
5. **医療情報の免責事項** → 推奨：アプリ説明文に追記

---

## 📝 推奨：医療免責事項の追加

アプリ説明文の最後に以下を追加することを推奨します：

**日本語**:
```
【免責事項】
本アプリは医療機器ではなく、診断・治療目的での使用を意図していません。
心理的な問題や健康上の懸念がある場合は、専門医にご相談ください。
```

**英語**:
```
【Disclaimer】
This app is not a medical device and is not intended for diagnosis or treatment purposes.
If you have psychological issues or health concerns, please consult a medical professional.
```
