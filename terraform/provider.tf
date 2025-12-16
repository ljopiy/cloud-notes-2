terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.96.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "yandex" {
  service_account_key_file = "../sa_key.json"
  cloud_id                 = var.yc_cloud_id
  folder_id                = var.yc_folder_id
  zone                     = "ru-central1-a"
}

provider "random" {
  # Не требует дополнительной настройки
}
