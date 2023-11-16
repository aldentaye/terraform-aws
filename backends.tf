# --- root/backends.tf ---

terraform {
  cloud {
    organization = ""

    workspaces {
      name = "dev"
    }
  }
}
