# 🔴 最重要：データ取得の安定化（RPC一時解除）

## 背景
ホーム画面と気分詳細画面でデータが正しく表示されない。
RPC関数 `get_dashboard_data` が複雑すぎてデバッグ困難。

## コンセプト
**「まずシンプルに動かす、その後最適化する」**

### Phase 1: RPC解除（今やる）
- RPC関数を使わず、各テーブルに直接アクセス
- ホーム画面 → `daily_results` テーブル
- 気分詳細画面 → `spot_results` テーブル
- 動作確認して安定させる

### Phase 2: RPC再導入（将来）
- すべて安定したら、パフォーマンス最適化としてRPCを再導入
- RPCはチューニング手段であり、最初から必須ではない

## 影響範囲
- `SupabaseDataManager.swift` - 新メソッド追加
- `SimpleDashboardView.swift` - RPC → 直接アクセスに変更

## データソース
- **ホーム画面**: `daily_results` テーブル
- **気分詳細**: `spot_results` テーブル
