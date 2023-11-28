terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "./key.json"
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "bingonet" {}

resource "yandex_vpc_subnet" "bingonet" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.bingonet.id
  v4_cidr_blocks = ["10.0.0.0/16"]
}

locals {
  folder_id = "b1gchsq9rppdno9li997"
  service-accounts = toset([
    "bingo-sa",
  ])
  bingo-sa-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}
resource "yandex_resourcemanager_folder_iam_member" "bingo-roles" {
  for_each  = local.bingo-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "cimage" {
  family = "ubuntu-2204-lts"
}

# DB - Database
resource "yandex_compute_instance" "db" {
  name = "db"
  zone = "ru-central1-a"
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "8"
      image_id = "fd89cudngj3s2osr228p"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.bingonet.id
    ip_address = "10.0.0.6"
    nat        = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa db.playbook.yml"
  }
}


# Bingo VM1
resource "yandex_compute_instance" "bingo1" {
  name = "bingo1"
  zone = "ru-central1-a"
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
  depends_on = [ yandex_compute_instance.db ]

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "8"
      image_id = "fd89cudngj3s2osr228p"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.bingonet.id
    ip_address = "10.0.0.4"
    nat        = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa bingo.playbook.yml"
  }
}

# Bingo VM2
resource "yandex_compute_instance" "bingo2" {
  name = "bingo2"
  zone = "ru-central1-a"
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
  depends_on = [ yandex_compute_instance.db ]

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "8"
      image_id = "fd89cudngj3s2osr228p"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.bingonet.id
    ip_address = "10.0.0.5"
    nat        = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa bingo.playbook.yml"
  }
}

# ALB - Application Load Balancer
resource "yandex_compute_instance" "alb" {
  name = "alb"
  zone = "ru-central1-a"
  platform_id        = "standard-v2"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
  depends_on = [ yandex_compute_instance.bingo1, yandex_compute_instance.bingo2, yandex_compute_instance.db ]

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      type     = "network-hdd"
      size     = "8"
      image_id = "fd89cudngj3s2osr228p"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.bingonet.id
    ip_address = "10.0.0.3"
    nat        = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa alb.playbook.yml"
  }

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${yandex_compute_instance.bingo1.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa finish.playbook.yml"
  }
}