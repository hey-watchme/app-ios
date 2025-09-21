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
--   behavior_report: behavior_summaryテーブルのデータ
--   emotion_report: emotion_opensmile_summaryテーブルのデータ
--   subject_info: subjectsテーブルのデータ（devicesテーブル経由）
--   dashboard_summary: dashboard_summaryテーブルのデータ（気分データはここから取得）
--   subject_comments: subject_commentsテーブルのデータ（対象日付のコメントのみ）
-- ========================================

DROP FUNCTION IF EXISTS get_dashboard_data(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_dashboard_data(
    p_device_id TEXT,
    p_date TEXT
)
RETURNS TABLE (
    behavior_report JSONB,
    emotion_report JSONB,
    subject_info JSONB,
    dashboard_summary JSONB,
    subject_comments JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
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
         LIMIT 1) AS dashboard_summary,
         
        -- subject_comments: コメントデータを取得
        -- 観測対象に紐づくコメントを取得し、ユーザー情報も含める
        -- 重要: 日付でフィルタリングして、選択された日付のコメントのみ取得
        (SELECT jsonb_agg(
            jsonb_build_object(
                'comment_id', comment_id,
                'subject_id', subject_id,
                'user_id', user_id,
                'comment_text', comment_text,
                'created_at', created_at,
                'date', date,
                'user_name', user_name,
                'user_avatar_url', user_avatar_url
            ) ORDER BY created_at DESC
         )
         FROM (
             SELECT 
                 sc.comment_id,
                 sc.subject_id,
                 sc.user_id,
                 sc.comment_text,
                 sc.created_at,
                 sc.date,
                 u.name as user_name,
                 u.avatar_url as user_avatar_url
             FROM subject_comments sc
             LEFT JOIN public.users u ON sc.user_id = u.user_id
             WHERE sc.subject_id = (
                 SELECT s.subject_id 
                 FROM subjects s
                 INNER JOIN devices d ON s.subject_id = d.subject_id
                 WHERE d.device_id = p_device_id::uuid
                 LIMIT 1
             )
             AND sc.date = p_date::date  -- 日付でフィルタリング（重要）
             ORDER BY sc.created_at DESC
             LIMIT 50
         ) AS comments_with_users
        ) AS subject_comments;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_dashboard_data(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_data(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_dashboard_data(TEXT, TEXT) TO service_role;