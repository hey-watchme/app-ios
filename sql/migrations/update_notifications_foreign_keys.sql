-- notificationsとnotification_readsテーブルの外部キー制約を変更
-- auth.users(id) から public.users(user_id) への参照に変更

-- ========================================
-- 1. notifications.user_idの変更
-- ========================================
-- 既存の外部キー制約を削除
ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

-- 新しい外部キー制約を追加（public.users.user_idへの参照）
-- NULLを許可（グローバル通知の場合はuser_idがNULL）
ALTER TABLE notifications 
ADD CONSTRAINT notifications_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES public.users(user_id) 
ON DELETE CASCADE;

-- インデックスも追加（パフォーマンス向上のため）
CREATE INDEX IF NOT EXISTS idx_notifications_user_id 
ON notifications(user_id);

-- ========================================
-- 2. notification_reads.user_idの変更
-- ========================================
-- 既存の外部キー制約を削除
ALTER TABLE notification_reads 
DROP CONSTRAINT IF EXISTS notification_reads_user_id_fkey;

-- 新しい外部キー制約を追加（public.users.user_idへの参照）
ALTER TABLE notification_reads 
ADD CONSTRAINT notification_reads_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES public.users(user_id) 
ON DELETE CASCADE;

-- インデックスも追加（パフォーマンス向上のため）
CREATE INDEX IF NOT EXISTS idx_notification_reads_user_id 
ON notification_reads(user_id);

-- 注意事項:
-- この変更を実行する前に、すべてのnotifications.user_idと
-- notification_reads.user_idがpublic.usersテーブルに存在することを確認してください。
-- グローバル通知（user_id = NULL）は影響を受けません。