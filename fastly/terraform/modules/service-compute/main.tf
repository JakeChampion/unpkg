resource "fastly_service_compute" "app" {
  name = var.compute_name

  force_destroy = false

  package {
    filename         = "../../../pkg/package.tar.gz"
    source_code_hash = filesha512("../../../pkg/package.tar.gz")
  }

  backend {
    name    = "npm"
    address = "registry.npmjs.org"
    port    = 443
    use_ssl = true
    override_host = "registry.npmjs.org"
    ssl_cert_hostname = "registry.npmjs.org"
  }

  dynamic "domain" {
    for_each = var.compute_domains
    content {
      name = domain.value["name"]
    }
  }
}