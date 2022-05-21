terraform {
  cloud {
    organization = "augustkang"
    workspaces {
      name = "infrastructure"
    }
  }
}
