-- user_devicesテーブルのRLSポリシーを修正するSQL

-- 1. まず現在のポリシーを確認（参考用）
-- SELECT * FROM pg_policies WHERE tablename = 'user_devices';

-- 2. RLSが有効になっていることを確認
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- 3. 既存のポリシーを削除（もし存在する場合）
DROP POLICY IF EXISTS "Users can view their own device associations" ON user_devices;
DROP POLICY IF EXISTS "Users can insert their own device associations" ON user_devices;
DROP POLICY IF EXISTS "Users can update their own device associations" ON user_devices;
DROP POLICY IF EXISTS "Users can delete their own device associations" ON user_devices;

-- 4. 新しいポリシーを作成

-- SELECTポリシー: ユーザーは自分のレコードのみ表示可能
CREATE POLICY "Users can view their own device associations" 
ON user_devices FOR SELECT 
USING (auth.uid() = user_id);

-- INSERTポリシー: ユーザーは自分のuser_idのレコードのみ挿入可能
CREATE POLICY "Users can insert their own device associations" 
ON user_devices FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- UPDATEポリシー: ユーザーは自分のレコードのみ更新可能
CREATE POLICY "Users can update their own device associations" 
ON user_devices FOR UPDATE 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETEポリシー: ユーザーは自分のレコードのみ削除可能
CREATE POLICY "Users can delete their own device associations" 
ON user_devices FOR DELETE 
USING (auth.uid() = user_id);

-- 5. サービスロール用のポリシー（必要に応じて）
-- サービスロールは全てのアクセスを許可
CREATE POLICY "Service role has full access" 
ON user_devices FOR ALL 
USING (auth.role() = 'service_role');

-- 6. テーブルの権限を確認
GRANT ALL ON user_devices TO authenticated;
GRANT ALL ON user_devices TO service_role;

-- 7. テスト用のクエリ（実行後に削除してください）
-- 現在のユーザーIDを確認
-- SELECT auth.uid();

-- user_devicesテーブルの内容を確認
-- SELECT * FROM user_devices WHERE user_id = auth.uid();

-- 手動でレコードを挿入してみる（device_idは実際のものに置き換えてください）
-- INSERT INTO user_devices (user_id, device_id, role) 
-- VALUES (auth.uid(), '95f4e6ce-3b80-41ce-ae28-61306a738f52', 'owner');