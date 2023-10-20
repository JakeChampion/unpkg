terraform {
  cloud {
    organization = "unpkg"

    workspaces {
      name = "unpkg-staging"
    }
  }

  required_version = ">= 1.1.2"
}