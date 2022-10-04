provider "azurerm" {
    features {}
}

#Criando o resource group 
resource "azurerm_resource_group" "projetomba" {
  name = "projetomba"
  location = "westus3"


   tags = {
    environment = "Production"
  }
}

#Criando a vnet
resource "azurerm_virtual_network" "vnet" {
  name = "centos7-vnet"
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.projetomba.location
  resource_group_name = azurerm_resource_group.projetomba.name

   tags = {
    environment = "Production"
  }
}


#Criando a subnet 
resource "azurerm_subnet" "subnet" {
     name = "centos7-subnet"
     resource_group_name = azurerm_resource_group.projetomba.name
     virtual_network_name = azurerm_virtual_network.vnet.name
     address_prefixes = ["10.0.3.4"]
}

 
resource "azurerm_network_security_group" "nsg" {
  name                = "securitygroupprojeto"
  location            = azurerm_resource_group.projetomba.location
  resource_group_name = azurerm_resource_group.projetomba.name

  security_rule {
    name                       = "Portas ssh, http e https"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  

  tags = {
    environment = "Production"
  }
}

#Criando o ip publico
resource "azurerm_public_ip" "publicip" {
name                = "publicip1"
resource_group_name = azurerm_resource_group.projetomba.name
location            = azurerm_resource_group.projetomba.location
  allocation_method   = "Static"

 tags = {
   environment = "Production"
}
}

#Criando a nic 
resource "azurerm_network_interface" "nic" {
  name = "nic"
  location = azurerm_resource_group.projetomba.location
  resource_group_name = azurerm_resource_group.projetomba.name
  
  ip_configuration {
    name = "interno"
    subnet_id = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.publicip.id
    
  }
}

 

resource "azurerm_network_interface_security_group_association" "securitygroup" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


resource "azurerm_linux_virtual_machine" "Saltmaster" {
  name                = "saltmaster"
  resource_group_name = azurerm_resource_group.projetomba.name
  location            = azurerm_resource_group.projetomba.location
  size                = "Standard_F1"
  network_interface_ids = [azurerm_network_interface.nic.id]
  disable_password_authentication = true
  admin_username      = "master"


    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }
    admin_ssh_key  {
        username   = "master"
        public_key = file("~/.ssh/id_rsa.pub")
    }

    source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5"
    version   = "latest"
  }

   provisioner "remote-exec" {
      inline = [
        "sudo yum -y install httpd && sudo systemctl start httpd",
        "sudo yum -y update && sudo yum upgrade",
        "sudo yum -y install vim",
        "sudo yum -y install epel-release",
        "sudo mkdir /home/www",
        "echo BOMBANDO O SALTMASTER TAMBÉMMMMM"
      ]

      connection {
        type = "ssh"
        host = azurerm_public_ip.publicip.ip_address
        user = "master"
        private_key = file("~/.ssh/id_rsa")
         
      }
 }
}

resource "azurerm_managed_disk" "disco1" {
        name                 = "disco1"
        location             = azurerm_resource_group.projetomba.location
        create_option        = "Empty"
        disk_size_gb         = 2000
        resource_group_name  = azurerm_resource_group.projetomba.name
        storage_account_type = "Standard_LRS"
}

    resource "azurerm_virtual_machine_data_disk_attachment" "disco1" {
        virtual_machine_id = azurerm_linux_virtual_machine.Saltmaster.id
        managed_disk_id    = azurerm_managed_disk.disco1.id
        lun                = 0
        caching            = "None"
}

 

