
resource "google_service_account" "default" {
  count        = var.module_enabled ? 1 : 0
  account_id   = "${var.deploy_name}-${var.region}"
  display_name = "${var.deploy_name}-${var.region}"
}

resource "google_project_iam_member" "default" {
  count  = var.module_enabled ? length(var.roles) : 0
  project = var.gcp_project
  role   = element(var.roles, count.index)
  member = "serviceAccount:${google_service_account.default[0].email}"
}

resource "google_service_account_key" "default" {
  count              = var.module_enabled ? 1 : 0
  depends_on         = [google_service_account.default]
  service_account_id = google_service_account.default[0].name
}

//resource "kubernetes_cluster_role_binding" "cluster-admin" {
//  count = var.module_enabled ? 1 : 0
//  metadata {
//    name = "${var.deploy_name}-binding"
//  }
//  role_ref {
//    api_group = "rbac.authorization.k8s.io"
//    kind      = "ClusterRole"
//    name      = "cluster-admin"
//  }
//  subject {
//    api_group = "rbac.authorization.k8s.io"
//    kind      = "User"
//    name      = google_service_account.default[0].account_id
//  }
//}

