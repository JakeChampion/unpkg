compute_name = "development-unpkg.edgecompute.app"

compute_domains = [
  {
    name = "development-unpkg.edgecompute.app"
  }
]

vcl_name = "dev-unpkg.jakechampion.name"
vcl_backends = [
  {
    name                  = "compute_at_edge"
    address               = "development-unpkg.edgecompute.app"
    port                  = 443
    ssl_cert_hostname     = "*.edgecompute.app"
    auto_loadbalance      = false
    connect_timeout       = 5000
    first_byte_timeout    = 120000
    between_bytes_timeout = 120000
    error_threshold       = 0
    override_host         = "development-unpkg.edgecompute.app"
    ssl_sni_hostname      = "development-unpkg.edgecompute.app"
    use_ssl               = true
  },
  {
    name                  = "fly"
    address               = "unpkg.fly.dev"
    port                  = 443
    ssl_cert_hostname     = "unpkg.fly.dev"
    auto_loadbalance      = false
    connect_timeout       = 5000
    first_byte_timeout    = 120000
    between_bytes_timeout = 120000
    error_threshold       = 0
    override_host         = "unpkg.fly.dev"
    ssl_sni_hostname      = "unpkg.fly.dev"
    use_ssl               = true
  }
]


vcl_domains = [
  {
    name = "dev-unpkg.jakechampion.name"
  }
]