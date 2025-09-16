-- ========================================
-- RPC関数: get_dashboard_data
-- ========================================
-- 最終更新: 2025-09-16
-- 
-- 説明: ダッシュボード表示用の統合データ取得関数
-- 
-- パラメータ:
--   p_device_id: TEXT - デバイスID（UUID形式の文字列）
--   p_date: TEXT - 日付（YYYY-MM-DD形式）
-- 
-- 戻り値:
--   vibe_report: vibe_whisper_summaryテーブルのデータ
--   behavior_report: behavior_summaryテーブルのデータ
--   emotion_report: emotion_opensmile_summaryテーブルのデータ
--   subject_info: subjectsテーブルのデータ（devicesテーブル経由）
--   dashboard_summary: dashboard_summaryテーブルのデータ
-- ========================================

DROP FUNCTION IF EXISTS get_dashboard_data(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_dashboard_data(
    p_device_id TEXT,
    p_date TEXT
)
RETURNS TABLE (
    vibe_report JSONB,
    behavior_report JSONB,
    emotion_report JSONB,
    subject_info JSONB,
    dashboard_summary JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- vibe_report: vibe_whisper_summaryテーブルから取得
        (SELECT to_jsonb(t.*) 
         FROM vibe_whisper_summary t 
         WHERE t.device_id = p_device_id 
         AND t.date = p_date::date 
         LIMIT 1) AS vibe_report,
         
        -- behavior_report: behavior_summaryテーブルから取得
        (SELECT to_jsonb(t.*) 
         FROM behavior_summary t 
         WHERE t.device_id = p_device_id 
         AND t.date = p_date::date 
         LIMIT 1) AS behavior_report,
         
        -- emotion_report: emotion_opensmile_summaryテーブルから取得
        (SELECT to_jsonb(t.*) 
         FROM emotion_opensmile_summary t 
         WHERE t.device_id = p_device_id 
         AND t.date = p_date::date 
         LIMIT 1) AS emotion_report,
         
        -- subject_info: subjectsテーブルから取得（devicesテーブル経由）
        -- 注意: devicesのdevice_idはUUID型
        (SELECT to_jsonb(s.*) 
         FROM subjects s
         INNER JOIN devices d ON s.subject_id = d.subject_id
         WHERE d.device_id = p_device_id::uuid 
         LIMIT 1) AS subject_info,
         
        -- dashboard_summary: dashboard_summaryテーブルから取得
        -- 注意: dashboard_summaryのdevice_idはUUID型
        -- このテーブルには以下の重要なフィールドが含まれる：
        --   - average_vibe: 本日の平均スコア
        --   - vibe_scores: 時系列スコアデータ（グラフ用）
        --   - analysis_result: {cumulative_evaluation: [...]} 形式のサマリー文章
        (SELECT to_jsonb(ds.*) 
         FROM dashboard_summary ds
         WHERE ds.device_id = p_device_id::uuid 
         AND ds.date = p_date::date
         LIMIT 1) AS dashboard_summary;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_dashboard_data(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_data(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_dashboard_data(TEXT, TEXT) TO service_role;