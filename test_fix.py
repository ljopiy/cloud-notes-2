import requests
import os
from datetime import datetime

print("=" * 50)
print("🚀 ТЕСТ РЕАЛЬНОЙ ЗАГРУЗКИ В YANDEX CLOUD")
print("=" * 50)

# 1. Создаем заметку
print("\n1. 📝 Создаем тестовую заметку...")
response = requests.post('http://localhost:5000/api/notes', json={
    'title': 'Тест реального Yandex Cloud Storage',
    'content': f'Тест загрузки файлов в облако\nВремя: {datetime.now().isoformat()}'
})

if response.status_code != 201:
    print(f"❌ Ошибка создания заметки: {response.text}")
    exit(1)

note = response.json()
note_id = note['id']
print(f"✅ Заметка создана: ID {note_id}")

# 2. Создаем тестовый файл
print(f"\n2. 📄 Создаем тестовый файл...")
filename = f"test_yandex_real_{datetime.now().strftime('%H%M%S')}.txt"
content = f"""✅ ТЕСТОВЫЙ ФАЙЛ В YANDEX CLOUD
==============================
Заметка ID: {note_id}
Время создания: {datetime.now().isoformat()}
Содержимое: Этот файл загружен в Yandex Object Storage
Бакет: cloud-notes-attachments
Статус: Тестирование реального облачного хранилища
"""

with open(filename, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ Файл создан: {filename}")
print(f"📋 Содержимое:\n{'-'*30}\n{content}\n{'-'*30}")

# 3. Загружаем файл в Yandex Cloud
print(f"\n3. ☁️  Загружаем файл в Yandex Cloud...")
with open(filename, 'rb') as f:
    files = {'file': (filename, f, 'text/plain')}
    response = requests.post(f'http://localhost:5000/api/notes/{note_id}/attach', files=files)

print(f"📤 Статус загрузки: {response.status_code}")

if response.status_code == 201:
    result = response.json()
    print(f"✅ УСПЕХ! Файл загружен в Yandex Cloud!")
    print(f"\n📊 Информация о файле:")
    print(f"   📛 Имя файла: {result['filename']}")
    print(f"   🆔 ID вложения: {result['id']}")
    print(f"   📍 Тип хранилища: {result.get('storage_type', 'yandex_cloud')}")
    print(f"   🔗 Публичный URL: {result['url']}")
    print(f"   🗺️  S3 путь: {result['storage_path']}")
    print(f"   🕐 Время загрузки: {result['uploaded_at']}")
    
    print(f"\n🔍 Проверка доступности файла...")
    try:
        import urllib.request
        with urllib.request.urlopen(result['url']) as web_file:
            downloaded_content = web_file.read().decode('utf-8')
            print(f"✅ Файл доступен из облака!")
            print(f"📄 Первые 200 символов:\n{'-'*30}")
            print(downloaded_content[:200])
            print(f"{'-'*30}")
    except Exception as e:
        print(f"⚠️  Не удалось скачать файл: {e}")
    
    print(f"\n🎯 Дальнейшие действия:")
    print(f"1. Откройте URL в браузере: {result['url']}")
    print(f"2. Проверьте бакет в Yandex Cloud Console")
    print(f"3. Удалите файл через API: DELETE /api/attachments/{result['id']}")
    
else:
    print(f"❌ Ошибка загрузки: {response.text}")
    print(f"\n🔧 Возможные причины:")
    print("1. Неправильные ключи доступа")
    print("2. Сервисный аккаунт не имеет прав storage.editor")
    print("3. Бакет не существует или недоступен")
    print("4. Проблемы с сетью")

# 4. Уборка
print(f"\n4. 🧹 Убираем временные файлы...")
if os.path.exists(filename):
    os.remove(filename)
    print(f"✅ Временный файл удален: {filename}")

print(f"\n" + "=" * 50)
print("🎉 ТЕСТ ЗАВЕРШЕН")
print("=" * 50)