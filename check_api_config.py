#!/usr/bin/env python3
"""
Avatar Uploader APIの設定確認
"""

import requests
import json

# APIエンドポイント
BASE_URL = "http://3.24.16.82:8014"

def check_api_config():
    """APIの実際の設定を確認"""
    print("🔍 Checking API configuration...")
    
    # ヘルスチェック
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ API is running")
            health_data = response.json()
            print(f"Response: {json.dumps(health_data, indent=2)}")
        else:
            print(f"❌ API returned status: {response.status_code}")
    except Exception as e:
        print(f"❌ Cannot connect to API: {e}")
        return
    
    # テストアップロードでS3設定を確認
    print("\n📤 Testing upload to check S3 configuration...")
    
    from PIL import Image
    import io
    
    # 小さな画像を作成
    img = Image.new('RGB', (10, 10), color='red')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    
    test_user_id = "test-" + "a" * 32  # テスト用の仮ID
    
    files = {
        "file": ("test.jpg", img_bytes, "image/jpeg")
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/v1/users/{test_user_id}/avatar",
            files=files,
            timeout=10
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code in [200, 201]:
            result = response.json()
            avatar_url = result.get('avatarUrl')
            print(f"\n📍 Returned S3 URL: {avatar_url}")
            
            # URLを解析
            if avatar_url:
                if "watchme-vault" in avatar_url:
                    print("⚠️ API is using watchme-vault bucket")
                elif "watchme-avatars" in avatar_url:
                    print("✅ API is using watchme-avatars bucket")
                
                if "us-east-1" in avatar_url:
                    print("⚠️ API is using us-east-1 region (incorrect)")
                elif "ap-southeast-2" in avatar_url:
                    print("✅ API is using ap-southeast-2 region (correct)")
        
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    check_api_config()