import boto3
import os
from datetime import datetime
from botocore.exceptions import ClientError

print("=== YANDEX OBJECT STORAGE SERVICE ===")

class SimpleYandexStorage:
    def __init__(self):
        self.bucket = 'cloud-notes-attachments'
        
        # НОВЫЕ КЛЮЧИ ОТ cloud-notes-storage-sa
        self.access_key = 'YCAJEGs7_4n17Ko-NHkl4d5-u'  # Идентификатор ключа
        self.secret_key = 'YCNc-5eTfh3p2mfaEOh50cHWtJ4CtrsSLScAThRp'  # Секретный ключ
        
        print(f"🔧 Configuring Object Storage:")
        print(f"   Bucket: {self.bucket}")
        print(f"   Access Key: {self.access_key[:10]}...")  # Показываем только часть
        print(f"   Service Account: cloud-notes-storage-sa")
        
        try:
            self.s3 = boto3.client(
                's3',
                endpoint_url='https://storage.yandexcloud.net',
                aws_access_key_id=self.access_key,
                aws_secret_access_key=self.secret_key,
                region_name='ru-central1'
            )
            print("✅ S3 client initialized")
            
            # Проверка подключения и прав
            try:
                # Проверяем, что можем получить список buckets
                response = self.s3.list_buckets()
                print(f"✅ Connected to Yandex Cloud S3")
                print(f"   Account has {len(response.get('Buckets', []))} buckets")
                
                # Ищем наш bucket
                bucket_found = False
                for bucket in response.get('Buckets', []):
                    if bucket['Name'] == self.bucket:
                        bucket_found = True
                        print(f"✅ Found bucket: {bucket['Name']}")
                        break
                
                if not bucket_found:
                    print(f"⚠️  Bucket '{self.bucket}' not found in this account")
                    print(f"   But it exists - might be in different folder")
                    
            except ClientError as e:
                error_code = e.response.get('Error', {}).get('Code', 'Unknown')
                error_msg = e.response.get('Error', {}).get('Message', 'No message')
                print(f"❌ Cannot access S3: {error_code}")
                print(f"   Message: {error_msg}")
                
                if error_code == 'InvalidAccessKeyId':
                    print(f"   🔑 ERROR: Invalid Access Key ID")
                elif error_code == 'SignatureDoesNotMatch':
                    print(f"   🔐 ERROR: Secret key doesn't match")
                    
                self.s3 = None
                
        except Exception as e:
            print(f"❌ Failed to create S3 client: {type(e).__name__}: {str(e)[:100]}")
            self.s3 = None
    
    def upload_file(self, file, note_id):
        """Загружает файл в Yandex Object Storage"""
        print(f"\n📤 UPLOAD REQUEST:")
        print(f"   Note ID: {note_id}")
        print(f"   File: {getattr(file, 'filename', 'No file')}")
        
        if not file or file.filename == '':
            print("❌ No file selected")
            return None
        
        if not self.s3:
            print("❌ S3 client not available")
            return None
        
        try:
            # Подготовка файла
            file.seek(0)
            file_content = file.read()
            original_filename = file.filename
            
            print(f"   File size: {len(file_content)} bytes")
            print(f"   Content type: {getattr(file, 'content_type', 'unknown')}")
            
            # Генерация ключа
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            # Делаем имя файла безопасным
            import re
            safe_filename = re.sub(r'[^\w\.\-]', '_', original_filename)
            key = f"notes/{note_id}/{timestamp}_{safe_filename}"
            
            print(f"   Storage key: {key}")
            print(f"   Target bucket: {self.bucket}")
            
            # Загрузка
            print(f"   Uploading to Yandex Cloud...")
            response = self.s3.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=file_content,
                ContentType=file.content_type or 'application/octet-stream',
                ACL='public-read'
            )
            
            # URL для доступа
            url = f"https://{self.bucket}.storage.yandexcloud.net/{key}"
            
            print(f"✅ UPLOAD SUCCESSFUL!")
            print(f"   URL: {url}")
            print(f"   ETag: {response.get('ETag', 'N/A')}")
            print(f"   File will be publicly accessible")
            
            return {
                'filename': original_filename,
                'storage_path': key,
                'url': url,
                'uploaded_at': datetime.now().isoformat()
            }
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            error_msg = e.response.get('Error', {}).get('Message', 'No message')
            
            print(f"❌ S3 ERROR: {error_code}")
            print(f"   Message: {error_msg}")
            
            # Подробная диагностика
            if error_code == 'AccessDenied':
                print(f"   🔑 ACCESS DENIED - Possible issues:")
                print(f"      1. Service account doesn't have storage.editor role")
                print(f"      2. Bucket policy restricts uploads")
                print(f"      3. Check IAM permissions for cloud-notes-storage-sa")
            elif error_code == 'NoSuchBucket':
                print(f"   📦 BUCKET NOT FOUND: '{self.bucket}'")
            elif error_code == 'InvalidAccessKeyId':
                print(f"   🔑 INVALID ACCESS KEY ID - check key")
            elif error_code == 'SignatureDoesNotMatch':
                print(f"   🔐 SIGNATURE ERROR - check secret key")
            
            return None
            
        except Exception as e:
            print(f"❌ UNEXPECTED ERROR: {type(e).__name__}: {str(e)}")
            import traceback
            traceback.print_exc()
            return None
    
    def delete_file(self, storage_path):
        """Удаляет файл из Object Storage"""
        try:
            if not self.s3:
                print("❌ No S3 client for deletion")
                return False
            
            print(f"🗑️  Deleting: {storage_path}")
            self.s3.delete_object(Bucket=self.bucket, Key=storage_path)
            print(f"✅ Deleted successfully")
            return True
            
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            print(f"❌ Delete failed: {error_code}")
            return False
        except Exception as e:
            print(f"❌ Unexpected delete error: {e}")
            return False

# Тест при прямом запуске
if __name__ == "__main__":
    print("\n🔍 TESTING STORAGE SERVICE WITH NEW KEYS...")
    storage = SimpleYandexStorage()
    
    if storage.s3:
        # Тестовая загрузка
        class MockFile:
            filename = "test_upload.txt"
            content_type = "text/plain"
            def read(self):
                return b"Test content from Cloud Notes API"
            def seek(self, pos):
                pass
        
        print("\n📤 Testing upload...")
        mock_file = MockFile()
        result = storage.upload_file(mock_file, 1)
        print(f"\n📋 Test result: {'Success' if result else 'Failed'}")
        if result:
            print(f"   URL: {result.get('url')}")
    else:
        print("\n❌ Cannot proceed - S3 client not available")