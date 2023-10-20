terraform {
  cloud {
    organization = "unpkg"

    workspaces {
      name = "unpkg-dev"
    }
  }

  required_version = ">= 1.1.2"
}