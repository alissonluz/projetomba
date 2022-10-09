provider "azurerm" {
  features {}
}

#Criando o resource group das vms do cluster
resource "azurerm_resource_group" "projetomba_vms" {
  name     = "projetomba_vms"
  location = "brazilsouth"

  tags = {
    environment = "Producao"
  }
}

#Criando a vnet para as vms do cluster 
resource "azurerm_virtual_network" "vnet_vms" {
  name                = "vnet_vms"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.projetomba_vms.location
  resource_group_name = azurerm_resource_group.projetomba_vms.name

  tags = {
    environment = "Producao"
  }
}

#Criando a subNet
resource "azurerm_subnet" "subnet_vms" {
  name                 = "subnet_vms"
  resource_group_name  = azurerm_resource_group.projetomba_vms.name
  virtual_network_name = azurerm_virtual_network.vnet_vms.name
  address_prefixes     = ["10.0.3.0/24"]


}

#Criando os discos para as vms
resource "azurerm_managed_disk" "projetomba_disk" {
  count                = 2
  name                 = "datadisk_existing_${count.index}"
  location             = azurerm_resource_group.projetomba_vms.location
  resource_group_name  = azurerm_resource_group.projetomba_vms.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"

  tags = {
    environment = "Producao"
  }
}

#Criando o security group e liberando as portas necessarias
resource "azurerm_network_security_group" "nsg_vms" {
  name                = "securitygroupprojeto"
  location            = azurerm_resource_group.projetomba_vms.location
  resource_group_name = azurerm_resource_group.projetomba_vms.name

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
    environment = "Producao"
  }
}

#Criando o ip publico
resource "azurerm_public_ip" "publicip_vms" {
  count               = 2
  name                = "publicip_vms${count.index}"
  location            = azurerm_resource_group.projetomba_vms.location
  resource_group_name = azurerm_resource_group.projetomba_vms.name
  allocation_method   = "Static"

  tags = {
    environment = "Producao"
  }
}

# Associando o security group a interface de rede
resource "azurerm_network_interface_security_group_association" "securitygroup" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.nic_vms[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg_vms.id


}

#Criando a interface de rede
resource "azurerm_network_interface" "nic_vms" {
  count               = 2
  name                = "nic_vms${count.index}"
  location            = azurerm_resource_group.projetomba_vms.location
  resource_group_name = azurerm_resource_group.projetomba_vms.name

  ip_configuration {
    name                          = "Interno"
    subnet_id                     = azurerm_subnet.subnet_vms.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip_vms[count.index].id
  }
  tags = {
    environment = "Producao"
  }
}


#Criando a chave publica
resource "azurerm_ssh_public_key" "projetomba_vms" {
  name                = "projetomba_vms"
  resource_group_name = azurerm_resource_group.projetomba_vms.name
  location            = azurerm_resource_group.projetomba_vms.location
  public_key          = file("~/.ssh/id_rsa.pub")

  tags = {
    environment = "Producao"
  }
}

#Criando as vms
resource "azurerm_linux_virtual_machine" "server" {
  count                           = 2
  name                            = "server${count.index}"
  location                        = azurerm_resource_group.projetomba_vms.location
  resource_group_name             = azurerm_resource_group.projetomba_vms.name
  network_interface_ids           = [azurerm_network_interface.nic_vms[count.index].id]
  size                            = "Standard_F1"
  disable_password_authentication = true
  admin_username                  = "maquina"

  os_disk {
    name                 = "myosdisk${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  admin_ssh_key {
    username   = "maquina"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5"
    version   = "latest"
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.publicip_vms[count.index].ip_address
    user        = "maquina"
    private_key = file("~/.ssh/id_rsa")
    timeout     = "1m"

  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install httpd && sudo systemctl start httpd",
      "sudo yum -y update && sudo yum upgrade",
      "sudo yum -y install vim",
      "sudo yum -y install epel-release",
      "sudo mkdir /home/testeibombou/",
      "echo INSTALACAO REALIZADA COM SUCESSO"
    ]


  }
}




//resource "azurerm_virtual_machine_data_disk_attachment" "projetomba_disk" {
//      virtual_machine_id =  azurerm_linux_virtual_machine.server[count.index]
///    managed_disk_id    =  azurerm_managed_disk.projetomba_disk[count.index]
// lun                = 0
//caching            = "None"
//}
 
