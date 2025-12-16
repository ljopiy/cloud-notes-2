# Cloud Notes - Базовая инфраструктура

# 1. Получаем информацию о существующей сети "default"
data "yandex_vpc_network" "existing" {
  network_id = "enpg9m58po6uhsi1jpk9"
}

# 2. Создаем подсеть в существующей сети
resource "yandex_vpc_subnet" "app_subnet" {
  name           = "cloud-notes-subnet"
  zone           = "ru-central1-a"
  network_id     = data.yandex_vpc_network.existing.id
  v4_cidr_blocks = ["192.168.30.0/24"]
}

# 3. Security Group в существующей сети
resource "yandex_vpc_security_group" "app_sg" {
  name        = "cloud-notes-sg"
  network_id  = data.yandex_vpc_network.existing.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HTTP from load balancer"
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH for administration"
  }

  ingress {
    protocol       = "TCP"
    port           = 5000
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Flask application port"
  }

  ingress {
    protocol       = "TCP"
    port           = 3306
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "MySQL public access"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Outbound traffic"
  }
}

# 4. Random ID для уникального имени бакета
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 5. Object Storage для файловых вложений
resource "yandex_storage_bucket" "attachments" {
  bucket     = "cloud-notes-attachments-${random_id.bucket_suffix.hex}"
  access_key = var.yc_access_key
  secret_key = var.yc_secret_key
  
  acl = "private"
  
  versioning {
    enabled = true
  }
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
  
  tags = {
    project     = var.project_name
    purpose     = "file-attachments"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# 6. Container Registry для Docker образов
resource "yandex_container_registry" "main" {
  name = "cloud-notes-registry"
  
  labels = {
    project     = var.project_name
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Сервисный аккаунт для Instance Group
resource "yandex_iam_service_account" "backend_sa" {
  name        = "backend-instance-sa"
  description = "Service account for backend instances"
}

resource "yandex_resourcemanager_folder_iam_member" "network_user" {
  folder_id = var.yc_folder_id
  role      = "vpc.user"
  member    = "serviceAccount:${yandex_iam_service_account.backend_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "compute_admin" {
  folder_id = var.yc_folder_id
  role      = "compute.admin"
  member    = "serviceAccount:${yandex_iam_service_account.backend_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.backend_sa.id}"
}

# 7. Managed MySQL кластер
resource "yandex_mdb_mysql_cluster" "main" {
  name        = "cloud-notes-mysql"
  environment = "PRESTABLE"
  network_id  = data.yandex_vpc_network.existing.id
  version     = "8.0"

  access {
    web_sql = true
  }

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  mysql_config = {
    sql_mode                       = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
    max_connections                = "100"
    default_authentication_plugin  = "MYSQL_NATIVE_PASSWORD"
    innodb_print_all_deadlocks     = "true"
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.app_subnet.id
  }

  security_group_ids = [yandex_vpc_security_group.app_sg.id]
}

# 8. База данных MySQL
resource "yandex_mdb_mysql_database" "notes_db" {
  cluster_id = yandex_mdb_mysql_cluster.main.id
  name       = "notes_db"
}

# 9. Пользователь MySQL
resource "yandex_mdb_mysql_user" "notes_user" {
  cluster_id = yandex_mdb_mysql_cluster.main.id
  name       = "notes_user"
  password   = "sGHZJklfcRp0bDxWiPAOTw=="
  
  permission {
    database_name = yandex_mdb_mysql_database.notes_db.name
    roles         = ["ALL"]
  }
}

# 10. Managed Instance Group для backend приложения
resource "yandex_compute_instance_group" "backend_ig" {
  name               = "cloud-notes-backend-ig"
  service_account_id = yandex_iam_service_account.backend_sa.id
  deletion_protection = false

  instance_template {
    platform_id = "standard-v2"
    
    resources {
      cores  = 2
      memory = 2
    }
    
    boot_disk {
      initialize_params {
        image_id = "fd827b91d99psvq5fjit"
        size     = 20
      }
    }
    
    network_interface {
      subnet_ids = [yandex_vpc_subnet.app_subnet.id]
      nat        = true
      security_group_ids = [yandex_vpc_security_group.app_sg.id]
    }
    
    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }
  
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  
  deploy_policy {
    max_unavailable = 1
    max_expansion   = 1
  }
  
  # ★ УДАЛИТЕ load_balancer секцию - создаем Target Group отдельно ★
}

# ★ СОЗДАЕМ TARGET GROUP ВРУЧНУЮ ★
resource "yandex_alb_target_group" "backend_tg" {
  name = "backend-tg"
  
  # Получаем IP-адреса инстансов из Instance Group
  # Используем data source, чтобы получить информацию после создания Instance Group
  dynamic "target" {
    for_each = yandex_compute_instance_group.backend_ig.instances
    content {
      subnet_id  = yandex_vpc_subnet.app_subnet.id
      ip_address = target.value.network_interface[0].ip_address
    }
  }
}

# HTTP Router для балансировщика
resource "yandex_alb_http_router" "app_router" {
  name = "cloud-notes-router"
}

# Backend Group для балансировщика
resource "yandex_alb_backend_group" "app_backend_group" {
  name = "cloud-notes-backend-bg"

  http_backend {
    name = "backend"
    
    # ★ ИСПОЛЬЗУЕМ ЯВНО СОЗДАННУЮ TARGET GROUP ★
    target_group_ids = [yandex_alb_target_group.backend_tg.id]
    
    # Health check для проверки работоспособности
    healthcheck {
      timeout  = "10s"
      interval = "2s"
      
      http_healthcheck {
        path = "/health"
      }
    }
    
    # Настройки балансировки
    load_balancing_config {
      panic_threshold = 50
    }
    
    port = 5000  # Порт Flask приложения
  }
}

# Правило маршрутизации для HTTP router
resource "yandex_alb_virtual_host" "app_virtual_host" {
  name           = "cloud-notes-host"
  http_router_id = yandex_alb_http_router.app_router.id
  
  # Все запросы направляем в backend group
  route {
    name = "all-routes"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.app_backend_group.id
      }
    }
  }
}

# Application Load Balancer
resource "yandex_alb_load_balancer" "app_balancer" {
  name = "cloud-notes-alb"
  network_id = data.yandex_vpc_network.existing.id
  
  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.app_subnet.id
    }
  }
  
  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        # Используем HTTP router
        http_router_id = yandex_alb_http_router.app_router.id
      }
    }
  }
}

# ========================
# OUTPUTS
# ========================

output "load_balancer_ip" {
  value = yandex_alb_load_balancer.app_balancer.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
  description = "Public IP address of the load balancer"
}

output "subnet_id" {
  value = yandex_vpc_subnet.app_subnet.id
}

output "security_group_id" {
  value = yandex_vpc_security_group.app_sg.id
}

output "network_info" {
  value = "Using existing network: ${data.yandex_vpc_network.existing.name} (ID: ${data.yandex_vpc_network.existing.id})"
}

output "bucket_name" {
  value = yandex_storage_bucket.attachments.bucket
}

output "bucket_url" {
  value = "https://${yandex_storage_bucket.attachments.bucket}.storage.yandexcloud.net"
}

output "registry_id" {
  value = yandex_container_registry.main.id
}

output "registry_name" {
  value = yandex_container_registry.main.name
}

output "mysql_host" {
  value = yandex_mdb_mysql_cluster.main.host[0].fqdn
}

output "mysql_port" {
  value = 3306
}

output "mysql_database" {
  value = yandex_mdb_mysql_database.notes_db.name
}

output "mysql_username" {
  value = yandex_mdb_mysql_user.notes_user.name
}

output "target_group_id" {
  value = yandex_alb_target_group.backend_tg.id
  description = "Target Group ID for load balancer"
}