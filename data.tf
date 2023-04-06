data "azurerm_storage_account" "mystorage" {
  name = "demostorageaccnarhe"
  resource_group_name = "demo-backend"
}

# terraform output -json nmaeofstorageaccount
output "nmaeofstorageaccount" {
  value = data.azurerm_storage_account.mystorage.location
  sensitive = false
}