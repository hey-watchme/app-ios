-- Subject情報のみを取得する軽量なRPC関数
-- get_dashboard_dataとは別に、HeaderViewから呼び出される専用関数

CREATE OR REPLACE FUNCTION get_subject_info(
    p_device_id TEXT
)
RETURNS TABLE (
    subject_info JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- subject_infoはdevice_idのみで検索（日付に関係ない）
        (SELECT to_jsonb(s) FROM subjects s
         JOIN devices d ON s.subject_id = d.subject_id
         WHERE d.device_id = p_device_id::uuid 
         LIMIT 1) AS subject_info;
END;
$$;

-- 関数の説明コメント
COMMENT ON FUNCTION get_subject_info IS 'デバイスIDからSubject情報のみを取得する軽量なRPC関数。HeaderViewなどSubject情報のみが必要な場合に使用。';