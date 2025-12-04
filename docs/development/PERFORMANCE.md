# パフォーマンス改善課題

最終更新: 2025-12-04 18:00

## 🚨 重要度：高（Critical Issues）

### 1. テキストフィールドのフォーカス時の長時間フリーズ ⭐⭐⭐

**現象**:
- テキストフィールドにフォーカスした際、**30秒近く待たされる**
- キーボードが表示されるまでアプリが完全にフリーズ
- ユーザー体験に致命的な影響

**発生箇所**:
- `SubjectRegistrationView.swift`: 観測対象の編集画面（名前、年齢、市区町村などの入力フィールド）
- その他の入力フォーム全般

**過去の試行錯誤**:
- ⚠️ **何ヶ月も前から改善を試みているが、未解決**
- 様々な修正を試みたが、根本的な解決には至っていない

### 🔴 2025年12月4日の改善試行と結果

**試行した改善策**:
1. UIViewRepresentable でネイティブUITextFieldをラップ（CustomTextField.swift）
2. SwiftUI TextFieldの完全置き換え（OptimizedTextField.swift、SimpleTextField.swift）
3. 日本語入力の予測変換を無効化（autocorrectionType = .no など）
4. デバウンス処理の最適化（300ms→100-200ms）
5. DeviceManagerの重複初期化防止
6. MVVMアーキテクチャへのリファクタリング（SubjectFormModel.swift）
7. computed propertyの削減とキャッシュ化
8. AsyncImageのURL再生成回避

**結果**: ❌ **完全に失敗**
- ログ上では11.34秒のHangと表示
- 実測では**20秒以上**のフリーズが継続
- 改善効果は**ゼロ**（数ヶ月にわたる試行で一度も改善せず）

**ログから判明した問題**:
```
Received external candidate resultset: Total number of candidates: 280
Result accumulator timeout: 0.250000, exceeded.
System gesture gate timed out.
```
- 日本語入力システムが280個もの予測変換候補を処理
- ただしテキストフィールドにフォーカスしただけで、文字入力前に発生
- SwiftUI/iOS システムレベルの問題の可能性が高い

**原因の推測**:
1. **キーボード表示時のメインスレッドブロッキング**
   - UIの再描画処理が重い可能性
   - 自動レイアウト制約の競合（ログに`Unable to simultaneously satisfy constraints`が頻出）

2. **環境変数や設定の読み込み**
   - テキストフィールドのフォーカス時に不要な処理が実行されている可能性

3. **デバッグログの過剰出力**
   - ログ出力が多すぎてパフォーマンスに影響している可能性

4. **SwiftUIのバグまたは既知の問題**
   - iOS/Xcode側の問題の可能性も

### 🎯 今後の方針

**残された選択肢**:
1. **根本的な回避策**
   - SubjectRegistrationView を完全に作り直す
   - フォーム入力を別画面に分離
   - モーダルではなくプッシュ遷移にする

2. **代替入力方法**
   - テキストフィールドの代わりにピッカーやセグメントコントロールを使用
   - 音声入力や外部キーボードのサポート

3. **プラットフォーム対応**
   - iOS 18以降での改善を待つ
   - SwiftUIの成熟を待つ
   - UIKitベースの画面に完全移行

4. **専門的な調査**
   - Instrumentsでの詳細なプロファイリング
   - Apple Developer Forumsでの類似事例の調査
   - SwiftUIの内部実装に詳しいエンジニアへの相談

**関連ログ**:
```
-[RTIInputSystemClient remoteTextInputSessionWithID:performInputOperation:]  perform input operation requires a valid sessionID. inputModality = Keyboard, inputOperation = <null selector>, customInfoType = UIEmojiSearchOperations
```

---

## 🔴 重要度：中（High Priority Issues）

### 2. アプリ全体の頻繁なHang（5-20秒）

**現象**:
- アプリ操作中に定期的に5-20秒程度のフリーズが発生
- ログに`Hang detected: 18.86s`、`Hang detected: 7.16s`などが頻出

**発生タイミング**:
- 画面遷移時
- データ取得時
- 地図生成時

**原因の推測**:
1. **地図スナップショット生成の重い処理**
   - `MapSnapshotGenerator.swift`のジオコーディング処理
   - 地域名 → 座標変換 → 地図画像生成の一連の処理が同期的

2. **データベースクエリの遅延**
   - Supabaseへの複数回のAPI呼び出し
   - データ取得後のUI更新がメインスレッドをブロック

3. **不要なデータ再取得**
   - デバウンス処理（300ms待機）が頻繁に発生
   - 画面遷移のたびに`DeviceManager.initializeDevices()`が実行される

**次のアクション**:
- [ ] 地図生成処理を完全に非同期化＋キャッシュ機構の導入
- [ ] データフェッチのバッチ処理化（複数クエリを1回にまとめる）
- [ ] 不要なデータ再取得を削減（キャッシュの有効活用）
- [ ] `@Published`プロパティの更新頻度を最適化

**関連ログ**:
```
⏳ [Debounce] Waiting 300ms before loading data for 2025-12-03...
Hang detected: 18.86s (debugger attached, not reporting)
Hang detected: 7.16s (debugger attached, not reporting)
Hang detected: 9.70s (debugger attached, not reporting)
```

---

### 3. 画面遷移時のデータ再取得の無駄

**現象**:
- 同じ画面に戻るたびに全データを再取得
- ネットワーク負荷とUI更新のオーバーヘッドが大きい

**発生箇所**:
- `SimpleDashboardView.swift`: ホーム画面
- `SubjectTabView.swift`: 観測対象画面
- `AnalysisView.swift`: レポート画面

**原因の推測**:
- SwiftUIの`onAppear`で毎回データ取得を実行
- キャッシュ機構が不十分
- `DeviceManager`と`SupabaseDataManager`の状態管理が分散

**次のアクション**:
- [ ] データキャッシュ戦略の再設計
- [ ] `onAppear`を`task(id:)`に置き換えて重複実行を防止
- [ ] データの有効期限（TTL）を設定
- [ ] ネットワーク状態に応じたキャッシュ優先モードの実装

---

## 🟡 重要度：低（Medium Priority Issues）

### 4. 自動レイアウト制約の競合

**現象**:
- コンソールに大量の制約エラーが出力
- UIのちらつきや描画遅延の原因になる可能性

**関連ログ**:
```
Unable to simultaneously satisfy constraints.
<NSLayoutConstraint:0x12b431c20 'accessoryView.bottom' ...>
<NSLayoutConstraint:0x11457cfa0 'assistantHeight' SystemInputAssistantView.height == 45 ...>
```

**次のアクション**:
- [ ] 制約の競合箇所を特定して修正
- [ ] SwiftUIの`frame()`と`padding()`の使い方を見直し

---

### 5. デバッグログの過剰出力

**現象**:
- アプリ起動からの短時間で340行以上のログが出力
- ログ出力自体がパフォーマンスに影響している可能性

**次のアクション**:
- [ ] 全ログを`#if DEBUG`で囲む
- [ ] ログレベル（VERBOSE/INFO/WARNING/ERROR）を導入
- [ ] Releaseビルドではログを完全に無効化

---

## 📊 パフォーマンス計測データ（2025-12-04時点）

| 操作 | 計測時間 | 目標値 | ステータス |
|------|---------|--------|-----------|
| アプリ起動 | 1.58秒 | <2秒 | ✅ 良好 |
| テキストフィールドのフォーカス | **30秒** | <0.5秒 | ❌ 致命的 |
| 画面遷移（ホーム→観測対象） | 7-18秒 | <1秒 | ❌ 深刻 |
| データ取得（daily_results） | 不明 | <1秒 | 🔍 要計測 |
| 地図生成（初回） | 不明 | <2秒 | 🔍 要計測 |

---

## 🛠️ 推奨ツールと計測方法

### 1. Instruments（Xcode標準ツール）

**Time Profiler**:
```bash
# 実機でプロファイリング実行
1. Xcode → Product → Profile (Cmd + I)
2. Time Profilerを選択
3. 問題の操作（テキストフィールドのフォーカス等）を実行
4. Call Treeで重い処理を特定
```

**System Trace**:
- CPUとGPUの使用状況を同時に可視化
- メインスレッドのブロッキングを検出

### 2. ログ分析スクリプト

```bash
# Hang検出
grep "Hang detected" /Users/kaya.matsumoto/Desktop/log.ini

# レイアウト制約エラー
grep "Unable to simultaneously satisfy constraints" /Users/kaya.matsumoto/Desktop/log.ini

# データフェッチの頻度
grep "Fetching" /Users/kaya.matsumoto/Desktop/log.ini | wc -l
```

---

## 🎯 優先順位付けと対応計画

### Phase 1: 緊急対応（1週間以内）
1. ✅ 地図のデフォルト表示を実装（完了: 2025-12-04）
2. 🔴 **テキストフィールドのフォーカス問題を解決**（最優先）
3. 🔴 Instrumentsで詳細プロファイリング実施

### Phase 2: パフォーマンス基盤改善（2週間以内）
1. 地図生成のキャッシュ機構
2. データフェッチの最適化（バッチ処理化）
3. デバッグログの条件付きコンパイル

### Phase 3: 継続的改善（1ヶ月以内）
1. データキャッシュ戦略の再設計
2. 自動レイアウト制約の最適化
3. パフォーマンス監視システムの導入

---

## 📚 参考資料

- [Apple - Improving Your App's Performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
- [SwiftUI Performance Tips](https://www.swiftbysundell.com/articles/swiftui-performance-tips/)
- [Optimizing SwiftUI View Updates](https://www.hackingwithswift.com/books/ios-swiftui/optimizing-swiftui-view-updates)

---

## 🔗 関連ドキュメント

- [README.md](../../README.md): アプリ全体の構成
- [TECHNICAL.md](../technical/TECHNICAL.md): 技術仕様
- [TROUBLESHOOTING.md](../operations/TROUBLESHOOTING.md): トラブルシューティング
