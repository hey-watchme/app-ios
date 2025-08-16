#!/usr/bin/env python3
"""
Avatar Uploader APIのテストスクリプト
iOSアプリと同じユーザーIDでテスト
"""

import requests
import sys
from PIL import Image
import io

# APIエンドポイント
BASE_URL = "http://3.24.16.82:8014"

# テスト用ユーザーID（iOSアプリのログから）
TEST_USER_ID = "164CBA5A-DBA6-4CBC-9B39-4EEA28D98FA5"

def test_health_check():
    """ヘルスチェック"""
    print("🔍 Testing health check...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        print(f"  Status: {response.status_code}")
        if response.status_code == 200:
            print("  ✅ API is running")
            return True
        else:
            print(f"  ❌ Unexpected status: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"  ❌ Connection error: {e}")
        return False

def test_user_avatar_upload():
    """ユーザーアバターのアップロードテスト"""
    print(f"\n📤 Testing avatar upload for user: {TEST_USER_ID}")
    
    # テスト用画像を作成（100x100の青い画像）
    img = Image.new('RGB', (100, 100), color='blue')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    
    # multipart/form-data でアップロード
    files = {
        "file": ("test_avatar.jpg", img_bytes, "image/jpeg")
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v1/users/{TEST_USER_ID}/avatar",
            files=files,
            timeout=10
        )
        
        print(f"  Status: {response.status_code}")
        print(f"  Response: {response.text}")
        
        if response.status_code in [200, 201]:
            result = response.json()
            avatar_url = result.get('avatarUrl')
            print(f"  ✅ Upload successful!")
            print(f"  📍 Avatar URL: {avatar_url}")
            
            # 画像が実際にアクセス可能か確認
            if avatar_url:
                test_image_access(avatar_url)
            return True
        else:
            print(f"  ❌ Upload failed")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"  ❌ Request error: {e}")
        return False
    except Exception as e:
        print(f"  ❌ Unexpected error: {e}")
        return False

def test_image_access(url):
    """アップロードされた画像へのアクセステスト"""
    print(f"\n🌐 Testing image access...")
    print(f"  URL: {url}")
    
    try:
        response = requests.head(url, timeout=5)
        print(f"  Status: {response.status_code}")
        
        if response.status_code == 200:
            print("  ✅ Image is accessible")
        elif response.status_code == 403:
            print("  ⚠️ Access denied (S3 permissions issue)")
        elif response.status_code == 404:
            print("  ❌ Image not found")
        else:
            print(f"  ❓ Unexpected status: {response.status_code}")
            
    except requests.exceptions.RequestException as e:
        print(f"  ❌ Cannot access image: {e}")

def main():
    print("=" * 60)
    print("Avatar Uploader API Test")
    print("=" * 60)
    
    # ヘルスチェック
    if not test_health_check():
        print("\n⚠️ API might not be running at", BASE_URL)
        sys.exit(1)
    
    # アバターアップロードテスト
    test_user_avatar_upload()
    
    print("\n" + "=" * 60)
    print("Test completed")
    print("=" * 60)

if __name__ == "__main__":
    main()