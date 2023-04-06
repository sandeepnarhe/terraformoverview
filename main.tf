terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

locals {
  web_server_name = var.environment == "production" ? "${var.web_server_name}-prod" : "${var.web_server_name}-dev"
}

resource "azurerm_resource_group" "web_server_rg" {
  name     = var.web_server_rg
  location = var.web_server_location

}

resource "azurerm_virtual_network" "web_server_vnet" {
  name                = "${var.resource_prefix}-vnet"
  resource_group_name = azurerm_resource_group.web_server_rg.name
  address_space       = [var.web_server_address_space]
  location            = var.web_server_location
  tags                = {
    webapp = local.web_server_name
  }
}


resource "azurerm_subnet" "web_server_subnet" {
  for_each = var.web_server_subnet

  name                 = each.key
  resource_group_name  = azurerm_resource_group.web_server_rg.name
  virtual_network_name = azurerm_virtual_network.web_server_vnet.name
  address_prefixes     = [each.value]

}

resource "azurerm_network_interface" "web_server_nic" {
  name                = "${var.web_server_name}-${format("%02d", count.index)}-nic"
  resource_group_name = azurerm_resource_group.web_server_rg.name
  location            = var.web_server_location
  count               = var.web_server_count
  ip_configuration {
    subnet_id                     = azurerm_subnet.web_server_subnet["web-server"].id
    private_ip_address_allocation = "Dynamic"
    name                          = "${var.web_server_name}-ip"
    public_ip_address_id          = count.index == 0 ? azurerm_public_ip.web_server_public_ip.id : null
  }

}

resource "azurerm_public_ip" "web_server_public_ip" {
  name                = "${var.web_server_name}-public-ip"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.web_server_rg.name
  allocation_method   = var.environment == "prod" ? "Static" : "Dynamic"
}


resource "azurerm_network_security_group" "web_server_nsg" {
  name                = "${var.web_server_name}-nsg"
  resource_group_name = azurerm_resource_group.web_server_rg.name
  location            = var.web_server_location
}

resource "azurerm_network_security_rule" "web_server_nsg_rdp_rule" {
  name                        = "RDP_Inbound"
  resource_group_name         = azurerm_resource_group.web_server_rg.name
  network_security_group_name = azurerm_network_security_group.web_server_nsg.name
  priority                    = 100
  direction                   = "Inbound"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  access                      = "Allow"
  protocol                    = "Tcp"
}


resource "azurerm_subnet_network_security_group_association" "web_server_nsg_association" {
  network_security_group_id = azurerm_network_security_group.web_server_nsg.id
  subnet_id                 = azurerm_subnet.web_server_subnet["web-server"].id
}


resource "azurerm_windows_virtual_machine" "web_server" {

  count = var.web_server_count

  name = "${var.web_server_name}-${format("%02d", count.index)}"

  location              = var.web_server_location
  resource_group_name   = azurerm_resource_group.web_server_rg.name
  network_interface_ids = [azurerm_network_interface.web_server_nic[count.index].id]
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  admin_password        = "P@$$w0rd1234!"
  availability_set_id   = azurerm_availability_set.web_server_avalibility_set.id
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServerSemiAnnual"
    sku       = "Datacenter-Core-1709-smalldisk"
    version   = "latest"
  }

}


resource "azurerm_availability_set" "web_server_avalibility_set" {
  name                        = "${var.web_server_name}-avalibility_set"
  location                    = var.web_server_location
  resource_group_name         = azurerm_resource_group.web_server_rg.name
  managed                     = true
  platform_fault_domain_count = 2
}

module "storage_account" {

  source = "./storage"
  location = "eastus"
  storage_account_rg = "demo"
  storage_account_name = "narhedemostorage"
  
}


/**
resource "azurerm_public_ip" "web_server_lb_public_ip" {
  name                = "${var.resource_prefix}-lb-public-ip"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.web_server_rg.name
  allocation_method   = var.environment == "production" ? "Static" : "Dynamic"

}

resource "azurerm_lb" "web_server_lb" {
  count = 1
  name                = "${var.resource_prefix}-lb"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.web_server_rg.name
  frontend_ip_configuration {
    name                 = "${var.resource_prefix}-lb-frontend-ip"
    public_ip_address_id = azurerm_public_ip.web_server_lb_public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "web_server_lb_backend_pool" {
  name            = "${var.resource_prefix}-lb-backend-pool"
  loadbalancer_id = azurerm_lb.web_server_lb.id

}

resource "azurerm_lb_probe" "web_server_lb_http_probe" {
  name            = "${var.resource_prefix}-lb-http-probe"
  loadbalancer_id = azurerm_lb.web_server_lb.id
  protocol        = "Tcp"
  port            = "80"
}

resource "azurerm_lb_rule" "web_server_lb_http_rule" {
  name                           = "${var.resource_prefix}-lb-http-rule"
  loadbalancer_id                = azurerm_lb.web_server_lb.id
  protocol                       = "Tcp"
  frontend_port                  = "80"
  backend_port                   = "80"
  frontend_ip_configuration_name = "${var.resource_prefix}-lb-frontend-ip"
  probe_id                       = azurerm_lb_probe.web_server_lb_http_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id]
}




resource "azurerm_windows_virtual_machine_scale_set" "web_server" {
  name                 = "${var.resource_prefix}-scale-set"
  location             = var.web_server_location
  resource_group_name  = azurerm_resource_group.web_server_rg.name
  admin_password       = "P@55w0rd1234!"
  admin_username       = "adminuser"
  computer_name_prefix = var.web_server_name
  sku                  = "Standard_F2"

instances = var.web_server_count

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServerSemiAnnual"
    sku       = "Datacenter-Core-1709-smalldisk"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }


  network_interface {
    name    = "web_server_network_profile"
    primary = true

    ip_configuration {
      name                                   = var.web_server_name
      primary                                = true
      subnet_id                              = azurerm_subnet.web_server_subnet["web-server"].id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id]
    }
  }




  extension {
    name                 = "${var.web_server_name}-extension"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.10"

    settings = <<SETTINGS
      {
        "fileUris": ["https://raw.githubusercontent.com/eltimmo/learning/master/azureInstallWebServer.ps1"],
        "commandToExecute": "start powershell -ExecutionPolicy Unrestricted -File azureInstallWebServer.ps1"
      }
      SETTINGS

  }
}

**/






















