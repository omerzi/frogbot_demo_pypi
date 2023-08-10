resource "azurerm_kubernetes_cluster" "k8s" {
  count               = var.module_enabled ? 1 : 0
  name                = "${var.deploy_name}-${var.region}"
  kubernetes_version  = var.cluster_version == "" ? "" : var.cluster_version
  location            = var.region
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.deploy_name}-${var.region}"
  sku_tier            = "Paid"

  //  api_server_authorized_ip_ranges = "${var.api_server_authorized_ip_ranges}"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = var.ssh_key
    }
  }

  default_node_pool {
    name                = "default"
    node_count          = var.node_count // Leaving this for K8S service to manage per load once already inisitalized , see Lifecycle
    vm_size             = var.node_size
    os_disk_size_gb     = var.node_disk_size_gb
    vnet_subnet_id      = var.subnet
    type                = "VirtualMachineScaleSets"
    max_pods            = "110"
    enable_auto_scaling = false
    min_count           = "1"
    max_count           = "8"
  }

  service_principal {
    client_id     = azuread_application.client.application_id
    client_secret = azuread_service_principal_password.client.value
  }

  tags = {
    Environment = var.environment
  }

  network_profile {
    network_plugin     = "kubenet"
    network_policy     = "calico"
    load_balancer_sku  = var.lb_sku
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      server_app_id     = azuread_application.server.application_id
      server_app_secret = azuread_service_principal_password.server.value
      client_app_id     = azuread_application.client.application_id
      tenant_id         = var.tenant_id
    }
  }
  depends_on = [
    azuread_service_principal_password.client,
    azuread_service_principal_password.server,
  ]

  lifecycle {
    //    ignore_changes = [ "default_node_pool.0.node_count" ]
    ignore_changes = [
      default_node_pool.0.node_count,
      default_node_pool.0.max_count,
      default_node_pool.0.min_count,
    ] // TODO: REMOVE VMSIZE till the end AFTER PIPELINE DEPLOYMENT
    //      "default_node_pool.0.vm_size",
    //      "service_principal.0.client_secret",
    //      "network_profile.0",
  }
}

provider "kubernetes" {
  host    = azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].host
  client_certificate = base64decode(
    azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_certificate,
  )
  client_key = base64decode(
    azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_key,
  )
  cluster_ca_certificate = base64decode(
    azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].cluster_ca_certificate,
  )
}

resource "kubernetes_cluster_role_binding" "cluster-admin" {
  count       = var.module_enabled ? 1 : 0
  metadata {
    name = "aks-cluster-admins"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = "administrators"
  }
  depends_on = [azurerm_kubernetes_cluster.k8s]
}

resource "kubernetes_service" "management-lb" {
  count = var.lb_sku == "basic" ? 1 : 0
  metadata {
    name = "management-lb"

    labels = {
      app  = "guestbook"
      tier = "frontend"
    }
  }

  spec {
    selector = {
      app  = "guestbook"
      tier = "frontend"
    }

    type = "LoadBalancer"

    port {
      port = 80
    }
  }
  depends_on = [azurerm_kubernetes_cluster.k8s]
}

