terraform {
  backend "azurerm" {
    resource_group_name  = "demo-backend"
    storage_account_name = "demostorageaccnarhe"
    container_name       = "tfstate"
    key                  = "web.tfstate"
  }
}


