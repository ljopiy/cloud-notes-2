echo "🚀 Initializing Cloud Notes project..."

# 1. Создаем структуру папок
mkdir -p terraform backend

# 2. Копируем ключ сервисного аккаунта (если еще нет)
if [ ! -f "sa_key.json" ]; then
    echo "❌ Error: sa_key.json not found in project root"
    echo "Please place your service account key file in the project root"
    exit 1
fi

# 3. Проверяем наличие YC CLI
if ! command -v yc &> /dev/null; then
    echo "📦 Installing Yandex Cloud CLI..."
    curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
    exec $SHELL
    yc init
fi

# 4. Получаем Cloud ID и Folder ID
echo "🔍 Getting Cloud and Folder IDs..."
YC_CLOUD_ID=$(yc config get cloud-id)
YC_FOLDER_ID=$(yc config get folder-id)

if [ -z "$YC_CLOUD_ID" ] || [ -z "$YC_FOLDER_ID" ]; then
    echo "⚠️  Could not get Cloud ID or Folder ID"
    echo "Please run: yc config set cloud-id YOUR_CLOUD_ID"
    echo "Please run: yc config set folder-id YOUR_FOLDER_ID"
    exit 1
fi

# 5. Создаем файл с переменными
cat > terraform/terraform.tfvars << EOF
yc_cloud_id  = "$YC_CLOUD_ID"
yc_folder_id = "$YC_FOLDER_ID"
db_password  = "$(openssl rand -base64 16)"
EOF

echo "✅ Project initialized!"
echo "📋 Next steps:"
echo "1. Review terraform/terraform.tfvars"
echo "2. Run: cd terraform && terraform init"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"