compute_name = "unpkg.edgecompute.app"

compute_domains = [
  {
    name = "unpkg.edgecompute.app"
  }
]

vcl_name = "unpkg-vcl"
vcl_backends = [
  {
    name                  = "compute_at_edge"
    address               = "unpkg.edgecompute.app"
    port                  = 443
    ssl_cert_hostname     = "*.edgecompute.app"
    auto_loadbalance      = false
    connect_timeout       = 5000
    first_byte_timeout    = 120000
    between_bytes_timeout = 120000
    error_threshold       = 0
    override_host         = "unpkg.edgecompute.app"
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
    use_ssl               = true
  }
]


vcl_domains = [
  {
    name = "unpkg.jakechampion.name"
  },
  {
    name = "mod.unpkg.jakechampion.name"
  }
]