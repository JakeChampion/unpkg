resource "fastly_service_vcl" "app" {
  name = var.vcl_name

  force_destroy = false

  dynamic "backend" {
    for_each = var.vcl_backends
    content {
      name                  = backend.value["name"]
      address               = backend.value["address"]
      port                  = backend.value["port"]
      ssl_cert_hostname     = backend.value["ssl_cert_hostname"]
      auto_loadbalance      = backend.value["auto_loadbalance"]
      connect_timeout       = backend.value["connect_timeout"]
      first_byte_timeout    = backend.value["first_byte_timeout"]
      between_bytes_timeout = backend.value["between_bytes_timeout"]
      error_threshold       = backend.value["error_threshold"]
      override_host         = backend.value["override_host"]
      ssl_sni_hostname      = backend.value["ssl_sni_hostname"]
      use_ssl               = backend.value["use_ssl"]
    }
  }

  dynamic "domain" {
    for_each = var.vcl_domains
    content {
      name= domain.value["name"]
    }
  }

  vcl {
    name    = "main.vcl"
    content = file("${path.module}/vcl/main.vcl")
    main    = true
  }

  vcl {
    name    = "breadcrumbs.vcl"
    content = file("${path.module}/vcl/breadcrumbs.vcl")
  }
}
