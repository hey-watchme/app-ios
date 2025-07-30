-- user_devicesテーブルにINSERTポリシーを追加するSQL
-- 
-- 問題: SELECTポリシーのみ設定されており、INSERTポリシーがないため、
-- 新規ユーザーのデバイス登録時にRLSエラーが発生している

-- INSERTポリシーを追加
CREATE POLICY "Users can insert their own device associations"
ON public.user_devices
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ポリシーが正しく設定されたか確認（オプション）
-- SELECT * FROM pg_policies WHERE tablename = 'user_devices';

-- 補足情報:
-- このポリシーにより、認証済みユーザーは自分のuser_idでのみ
-- user_devicesテーブルに新しいレコードを挿入できるようになります。
-- 他のユーザーのuser_idでの挿入は拒否されます。