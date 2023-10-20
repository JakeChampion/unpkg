terraform {
  cloud {
    organization = "unpkg"

    workspaces {
      name = "unpkg-production"
    }
  }

  required_version = ">= 1.1.2"
}