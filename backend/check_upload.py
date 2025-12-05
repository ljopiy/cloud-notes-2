# check_upload.py
import boto3
from botocore.exceptions import ClientError

print("=== Testing Upload to Public Bucket ===")

# Ваши ключи
ACCESS_KEY = 'ajehk67rbjnkictrqjb4'
SECRET_KEY = 'AQVN0aGPtc70kzu9TWSIpz8Sxp04S-Jh1bB7vTH2'
BUCKET = 'cloud-notes-attachments'

try:
    # 1. Создаем клиент с вашими ключами
    s3 = boto3.client(
        's3',
        endpoint_url='https://storage.yandexcloud.net',
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name='ru-central1'
    )
    print("✅ S3 client created")
    
    # 2. Пробуем загрузить тестовый файл
    test_key = 'test_upload.txt'
    test_content = b'Hello from Yandex Object Storage!'
    
    print(f"\n📤 Trying to upload to: {BUCKET}/{test_key}")
    
    try:
        response = s3.put_object(
            Bucket=BUCKET,
            Key=test_key,
            Body=test_content,
            ContentType='text/plain',
            ACL='public-read'  # Делаем файл публичным
        )
        
        print(f"✅ Upload successful!")
        print(f"   ETag: {response.get('ETag')}")
        print(f"   URL: https://{BUCKET}.storage.yandexcloud.net/{test_key}")
        
        # 3. Проверяем, что файл доступен публично
        print(f"\n🔗 Testing public access...")
        import urllib.request
        url = f'https://{BUCKET}.storage.yandexcloud.net/{test_key}'
        try:
            with urllib.request.urlopen(url) as response:
                content = response.read().decode('utf-8')
                print(f"✅ Public URL works! Content: {content}")
        except Exception as e:
            print(f"⚠️  Public URL access failed: {e}")
        
        # 4. Удаляем тестовый файл
        print(f"\n🗑️  Cleaning up...")
        s3.delete_object(Bucket=BUCKET, Key=test_key)
        print(f"✅ Test file deleted")
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_msg = e.response['Error']['Message']
        print(f"❌ Upload failed: {error_code}")
        print(f"   Message: {error_msg}")
        
        # Если Access Denied, ключи неверные или нет прав
        if error_code == 'AccessDenied':
            print(f"\n🔑 Access Denied - likely invalid keys")
            print(f"   Please check your access keys in Yandex Cloud Console")
            
except Exception as e:
    print(f"❌ Unexpected error: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()