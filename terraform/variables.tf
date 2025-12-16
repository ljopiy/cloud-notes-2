variable "yc_cloud_id" {
  type = string
}

variable "yc_folder_id" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project_name" {
  type    = string
  default = "cloud-notes"
}

variable "yc_access_key" {
  description = "Yandex Cloud Access Key for Object Storage"
  type        = string
  sensitive   = true
}

variable "yc_secret_key" {
  description = "Yandex Cloud Secret Key for Object Storage"
  type        = string
  sensitive   = true
}
