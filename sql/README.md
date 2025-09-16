# SQL管理ディレクトリ

## 📁 ディレクトリ構造

- `rpc_functions/` - Supabase RPC関数
  - `get_dashboard_data.sql` - ダッシュボードデータ取得関数
- `tables/` - テーブル定義（今後追加予定）
- `migrations/` - マイグレーションファイル（今後追加予定）

## ⚠️ 重要な注意事項

### RPC関数の更新時

1. **必ずこのディレクトリのSQLファイルを更新する**
2. **READMEに記載のSQL定義は参考程度に留める**
3. **変更履歴をSQLファイル内のコメントに記載する**

### get_dashboard_data関数について

この関数は以下のテーブルからデータを取得します：

- `vibe_whisper_summary` - 従来の心理データ（段階的に廃止予定）
- `behavior_summary` - 行動データ
- `emotion_opensmile_summary` - 感情データ
- `subjects` - 観測対象情報
- `dashboard_summary` - 新しい統合ダッシュボードデータ
  - `average_vibe` - 平均スコア
  - `vibe_scores` - グラフ用時系列データ
  - `analysis_result` - サマリー文章

### 型の注意点

- **device_id**の型が異なる：
  - `vibe_whisper_summary`: TEXT型
  - `behavior_summary`: TEXT型
  - `emotion_opensmile_summary`: TEXT型
  - `devices`: UUID型
  - `dashboard_summary`: UUID型

そのため、RPC関数内で適切な型キャストが必要です。

## 🔄 更新履歴

- 2025-09-16: 初回作成、dashboard_summary統合完了