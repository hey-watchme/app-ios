#!/usr/bin/env python3
"""
本番環境のAvatar Uploader APIテスト
"""

import requests
import sys
from PIL import Image
import io

# 本番APIエンドポイント
BASE_URL = "https://api.hey-watch.me/avatar"

# テスト用ユーザーID（iOSアプリのログから）
TEST_USER_ID = "164CBA5A-DBA6-4CBC-9B39-4EEA28D98FA5"

def test_health_check():
    """ヘルスチェック"""
    print("🔍 Testing health check...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        print(f"  Status: {response.status_code}")
        if response.status_code == 200:
            print("  ✅ Production API is running")
            print(f"  Response: {response.json()}")
            return True
        else:
            print(f"  ❌ Unexpected status: {response.status_code}")
            print(f"  Response: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"  ❌ Connection error: {e}")
        return False

def test_user_avatar_upload():
    """ユーザーアバターのアップロードテスト"""
    print(f"\n📤 Testing avatar upload for user: {TEST_USER_ID}")
    
    # テスト用画像を作成（500x500のグラデーション画像）
    img = Image.new('RGB', (500, 500))
    pixels = img.load()
    for i in range(500):
        for j in range(500):
            # グラデーション効果
            pixels[i, j] = (min(255, i//2), min(255, j//2), 128)
    
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG', quality=90)
    img_bytes.seek(0)
    
    # multipart/form-data でアップロード
    files = {
        "file": ("test_avatar.jpg", img_bytes, "image/jpeg")
    }
    
    try:
        print("  Sending request to:", f"{BASE_URL}/v1/users/{TEST_USER_ID}/avatar")
        response = requests.post(
            f"{BASE_URL}/v1/users/{TEST_USER_ID}/avatar",
            files=files,
            timeout=30,
            allow_redirects=True
        )
        
        print(f"  Status: {response.status_code}")
        print(f"  Response Headers: {dict(response.headers)}")
        print(f"  Response: {response.text[:500]}...")  # 最初の500文字
        
        if response.status_code in [200, 201]:
            try:
                result = response.json()
                avatar_url = result.get('avatarUrl') or result.get('avatar_url')
                print(f"  ✅ Upload successful!")
                print(f"  📍 Avatar URL: {avatar_url}")
                
                # 画像が実際にアクセス可能か確認
                if avatar_url:
                    test_image_access(avatar_url)
                return True
            except ValueError as e:
                print(f"  ❌ Invalid JSON response: {e}")
                return False
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
        # HEADリクエストでなくGETリクエストを使用（S3の設定による）
        response = requests.get(url, timeout=10, stream=True)
        print(f"  Status: {response.status_code}")
        
        if response.status_code == 200:
            content_type = response.headers.get('content-type', '')
            content_length = response.headers.get('content-length', 'unknown')
            print(f"  Content-Type: {content_type}")
            print(f"  Content-Length: {content_length} bytes")
            print("  ✅ Image is accessible")
        elif response.status_code == 301 or response.status_code == 302:
            print(f"  ↪️ Redirect to: {response.headers.get('location')}")
            # リダイレクト先にアクセス
            if response.headers.get('location'):
                redirect_response = requests.get(response.headers.get('location'), timeout=10)
                print(f"  Redirect Status: {redirect_response.status_code}")
                if redirect_response.status_code == 200:
                    print("  ✅ Image is accessible via redirect")
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
    print("Production Avatar Uploader API Test")
    print(f"Endpoint: {BASE_URL}")
    print("=" * 60)
    
    # ヘルスチェック
    if not test_health_check():
        print("\n⚠️ Production API might not be configured correctly at", BASE_URL)
        print("Check Nginx configuration for /avatar proxy pass")
    
    # アバターアップロードテスト
    test_user_avatar_upload()
    
    print("\n" + "=" * 60)
    print("Test completed")
    print("=" * 60)

if __name__ == "__main__":
    main()