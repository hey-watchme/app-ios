-- user_devicesテーブルのDELETEポリシーを確認・修正するSQL

-- 現在のRLSポリシーを確認
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_devices'
ORDER BY cmd;

-- DELETEポリシーが存在しない場合、または修正が必要な場合は以下を実行

-- 既存のDELETEポリシーを削除（存在する場合）
DROP POLICY IF EXISTS "Users can delete their own device associations" ON user_devices;

-- 新しいDELETEポリシーを作成
-- ユーザーは自分のデバイス連携のみを削除できる
CREATE POLICY "Users can delete their own device associations" ON user_devices
    FOR DELETE USING (auth.uid() = user_id);

-- 念のため、他の必要なポリシーも確認・作成

-- SELECTポリシー（自分のデバイス連携のみ表示）
DROP POLICY IF EXISTS "Users can view their own device associations" ON user_devices;
CREATE POLICY "Users can view their own device associations" ON user_devices
    FOR SELECT USING (auth.uid() = user_id);

-- INSERTポリシー（自分のデバイス連携のみ追加）
DROP POLICY IF EXISTS "Users can insert their own device associations" ON user_devices;
CREATE POLICY "Users can insert their own device associations" ON user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATEポリシー（必要に応じて）
DROP POLICY IF EXISTS "Users can update their own device associations" ON user_devices;
CREATE POLICY "Users can update their own device associations" ON user_devices
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RLSが有効になっていることを確認
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- ポリシーの再確認
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_devices'
ORDER BY cmd;