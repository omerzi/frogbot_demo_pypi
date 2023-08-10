

resource "azurerm_public_ip" "piplines-nat-public-ip" {
  count                   = var.module_enabled ? 1 : 0
  location                = var.region
  name                    = "${var.deploy_name}-${var.region}-piplines-nat"
  resource_group_name     = var.resource_group_name
  allocation_method       = "Static"
  sku                     = var.nat_public_ip_lb_sku
  idle_timeout_in_minutes = 30
  ip_version              = "IPv4"
  ip_tags = {}
  tags = {}
  zones  = lookup(var.aks_pp_map.override, "azurerm_public_ip_zones", ["1","2","3"])
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = lookup(var.aks_pp_map.override, "cluster_name","${var.deploy_name}-${var.region}")
  count               = var.module_enabled ? 1 : 0
  kubernetes_version  = lookup(var.aks_pp_map.override, "aks_version", "1.18.14")
  location            = var.region
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.deploy_name}-${var.region}"
  api_server_authorized_ip_ranges = concat(lookup(var.aks_pp_map.override, "api_server_authorized_ip_ranges"), var.api_server_authorized_ip_ranges)


  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = var.ssh_key
    }
  }

  identity {
    type = "SystemAssigned"
  }

    default_node_pool {
    name                = lookup(var.aks_pp_map.ng, "name", "default" )
    node_count          = lookup(var.aks_pp_map.ng, "desired_size", 1) // Leaving this for K8S service to manage per load once already inisitalized , see Lifecycle
    vm_size             = lookup(var.aks_pp_map.ng, "instance_type","Standard_D2s_v3")
    os_disk_size_gb     = lookup(var.aks_pp_map.ng, "disk_size", 2000)
    vnet_subnet_id      = var.subnet
    type                = "VirtualMachineScaleSets"
    max_pods            = "110"
    enable_auto_scaling = var.enable_auto_scaling
    node_labels         = lookup(var.aks_pp_map.ng, "labels", null)
    min_count           = lookup(var.aks_pp_map.ng, "min_size", 1)
    max_count           = lookup(var.aks_pp_map.ng, "max_size", 100)
    tags = {
      Environment                = var.environment
      cluster-autoscaler-enabled = "true"
      min                        = 3
      max                        = 100
    }
  }

#  service_principal { // TODO: remove once all cluster migrated to managed identity
#    client_id     = azuread_application.client.application_id
#    client_secret = azuread_service_principal_password.client.value
#  }

  tags = {
    Environment = var.environment
  }

  network_profile {
    network_plugin    = "kubenet"
    network_policy    = "calico"
    load_balancer_sku = var.lb_sku
    pod_cidr          = var.pod_cidr
    load_balancer_profile {
      //            managed_outbound_ip_count = 1 // TODO : Change once outbound_ip_address_ids fixed
      outbound_ip_address_ids = [azurerm_public_ip.piplines-nat-public-ip[0].id]
    }
  }

role_based_access_control_enabled = contains(keys(var.aks_pp_map.override), "disable_aad_rbac") != true

 dynamic "azure_active_directory_role_based_access_control" {
   for_each = contains(keys(var.aks_pp_map.override), "disable_aad_rbac") != true ? ["exec"] : []
      content {
      server_app_id     = azuread_application.server[0].application_id
      server_app_secret = azuread_service_principal_password.server[0].value
      client_app_id     = azuread_application.client[0].application_id
      tenant_id         = var.tenant_id
      }
   }
 
 depends_on = [ // TODO: remove once all cluster migrated to managed identity
   azuread_service_principal_password.client,
   azuread_service_principal_password.server,
 ]

  lifecycle {
    ignore_changes = [
      default_node_pool.0.node_count,
     # role_based_access_control.0.azure_active_directory.0,
    ]
  }
}

//data "azurerm_public_ip" "piplines-nat-public-ip" {
//  count                = var.module_enabled ? 1 : 0
//  name                = azurerm_public_ip.piplines-nat-public-ip[0].name
//  resource_group_name = var.resource_group_name
//  depends_on          = [azurerm_kubernetes_cluster.k8s]
//}
provider "kubernetes" {
  host                   = try(var.aks_pp_map.override["k8s_sdm"], try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].host, azurerm_kubernetes_cluster.k8s[0].kube_config[0].host))
  client_certificate     = base64decode(
  try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_certificate,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].client_certificate)
  )
  client_key             = base64decode(
  try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].client_key,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].client_key)
  )
  cluster_ca_certificate = base64decode(
  try(azurerm_kubernetes_cluster.k8s[0].kube_admin_config[0].cluster_ca_certificate,
  azurerm_kubernetes_cluster.k8s[0].kube_config[0].cluster_ca_certificate)
  )
}
resource "azurerm_kubernetes_cluster_node_pool" "pipelines_pool" {
  count                 = var.module_enabled ? 1 : 0
  name                =   lookup(var.aks_pp_map.pp, "name", "default" )
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s[0].id
  #vm_size               = var.node_size
  vm_size                = lookup(var.aks_pp_map.pp,"instance_type","Standard_D2s_v3")

  //  orchestrator_version  = "${var.cluster_version}" //TODO re-enable on newer versions
  enable_auto_scaling = var.enable_auto_scaling
  node_labels         = lookup(var.aks_pp_map.pp, "labels", null)
  min_count           = lookup(var.aks_pp_map.pp, "min_size", 1)
  max_count           = lookup(var.aks_pp_map.pp, "max_size", 100)
    tags = {
      Environment                = var.environment
      cluster-autoscaler-enabled = "true"
      min                        = 3
      max                        = 100
    }

  lifecycle {
    ignore_changes = [
      node_count,
      vnet_subnet_id,
    ]
  }
}


resource "azurerm_kubernetes_cluster_node_pool" "devops_nodegroup" {
  count                  = contains(keys(var.aks_pp_map),"devops") ? 1 : 0
  name                   = lookup(var.aks_pp_map.devops, "name", "devops" )
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s[0].id
  vm_size               = lookup(var.aks_pp_map.devops, "instance_type")
  node_taints           = ["pool_type=devops:NoSchedule"]
  enable_auto_scaling   = var.enable_auto_scaling
  min_count             = lookup(var.aks_pp_map.devops, "min_size", 1)
  max_count             = lookup(var.aks_pp_map.devops, "max_size", 100)
  os_disk_size_gb       = lookup(var.aks_pp_map.devops, "disk_size", 1000)
  node_labels           = {
    "k8s.jfrog.com/pool_type":"devops"
  }
  vnet_subnet_id        = var.subnet
  tags = {
    Environment                = var.environment
    cluster-autoscaler-enabled = "true"
    min                        = 3
    max                        = 100
  }

  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
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

