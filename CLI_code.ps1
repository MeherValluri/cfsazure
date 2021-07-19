az login



              ################################ CREATING  RESOURCES IN SEA REGION #################################

################################ CREATING A VIRTUAL NETWORK AND SUBNETS IN SEA REGION ###############################################

az group create --location southeastasia --name rgsoutheastasia

az network vnet create -g rgsoutheastasia -n cliseavnet --location southeastasia --address-prefixes 10.2.0.0/16 --subnet-name jumpportsubnet --subnet-prefixes 10.2.2.0/24

az network vnet subnet create -g rgsoutheastasia --vnet-name cliseavnet -n webserverSubnet --address-prefixes 10.2.1.0/24

############################### CREATING A RULE UNDER NSG AND ASSOCIATING WITH WEBSERVER SUBNET #########################################

az network nsg create --name nsgforws --resource-group rgsoutheastasia --location southeastasia
az network nsg rule create -g rgsoutheastasia --nsg-name nsgforws -n allowrdpforws --priority 1001 --source-address-prefixes 223.230.52.84 --source-port-ranges '*' --destination-address-prefixes 10.2.1.0/24 --destination-port-ranges 3389 --access Allow --protocol TCP --direction inbound --description 'allow_rdp_from_someip'
az network vnet subnet update -g rgsoutheastasia --vnet-name cliseavnet -n webserverSubnet --network-security-group nsgforws

############################### CREATING A RULE UNDER NSG AND ASSOCIATING WITH JUMPPORT SUBNET ################################################

az network nsg create --name nsgforjumpport --resource-group rgsoutheastasia --location southeastasia
az network nsg rule create -g rgsoutheastasia --nsg-name nsgforjumpport -n allowrdpforjumpport --priority 1001 --source-address-prefixes 223.230.52.84 --source-port-ranges '*' --destination-address-prefixes 10.2.2.0/24 --destination-port-ranges 3389 --access Allow --protocol TCP --direction inbound --description 'allow_rdp_from_someip'
az network vnet subnet update -g rgsoutheastasia --vnet-name cliseavnet -n jumpportSubnet --network-security-group nsgforjumpport


################################################## CREATING A LOAD BALANCER ###################################################################

az network public-ip create --name lbPublicIP -g rgsoutheastasia --allocation-method Static 

az network lb create -g rgsoutheastasia -n lbsea --sku Basic --public-ip-address lbPublicIP --backend-pool-name backendPool

az network lb probe create --lb-name lbsea -n lbhealthprobe --port 80 --protocol TCP -g rgsoutheastasia --interval 15

az network lb rule create -n lbrule --lb-name lbsea -g rgsoutheastasia --backend-port 80 --frontend-port 80 --protocol TCP --idle-timeout 15 --probe-name lbhealthprobe --backend-pool-name backendPool

az network lb inbound-nat-rule create -n RDPinboundNATrule -g rgsoutheastasia --lb-name lbsea --backend-port 3389 --frontend-port 3389 --protocol TCP

# az network lb address-pool create --lb-name lbsea -n backendPool --backend-address 10.2.1.0/24


#################################################### CREATING AN AVAILABIITY SET ################################################################

az vm availability-set create -n wsavailabilityset -g rgsoutheastasia --location southeastasia --platform-fault-domain-count 2 --platform-update-domain-count 2


############################################ CREATING AN NIC AND ASSOCIATED VM FOR WEB SERVERS ############################################

az network nic create -n webserverNIC1 -g rgsoutheastasia --subnet webserversubnet --vnet-name cliseavnet --location southeastasia --lb-inbound-nat-rules RDPinboundNATrule --lb-name lbsea --lb-address-pools backendPool 

az vm create -n webserver1 -g rgsoutheastasia --location southeastasia --availability-set wsavailabilityset --nics webserverNIC1 --size Standard_D1 --admin-password P@ssw0rd123! --admin-username mehervalluri --image MicrosoftWindowsServer:WindowsServer:2016-Datacenter:latest




az network nic create -n webserverNIC2 -g rgsoutheastasia --subnet webserversubnet --vnet-name cliseavnet --location southeastasia --lb-name lbsea --lb-address-pools backendPool

az vm create -n webserver2 -g rgsoutheastasia --location southeastasia --availability-set wsavailabilityset --nics webserverNIC2 --size Standard_D1 --admin-password P@ssw0rd123! --admin-username mehervalluri --image MicrosoftWindowsServer:WindowsServer:2016-Datacenter:latest


###############################################  CREATING A BACKUP FOR WEBSERVERS #######################################################

az backup vault create --location southeastasia -n backupvault -g rgsoutheastasia
az backup protection enable-for-vm -g rgsoutheastasia --vault-name backupvault --vm webserver1 --policy-name Defaultpolicy
az backup protection enable-for-vm -g rgsoutheastasia --vault-name backupvault --vm webserver2 --policy-name Defaultpolicy

az backup policy get-default-for-vm -g rgsoutheastasia --vault-name backupvault #to view the default policy details
az backup policy create --backup-management-type AzureWorkload --name VMbackuppolicy --policy {policy} -g rgsoutheastasia --workload-type VM # to create a new policy with the required details


###############################################  CREATING AN ALERT CONDITION FOR WEBSERVERS #######################################################

az vm list

az monitor metrics alert create -n alertforWS1 -g rgsoutheastasia --description "alert" --scopes /subscriptions/0ddb8f2f-e4c9-4460-94f9-84af943ebabf/resourceGroups/rgsoutheastasia/providers/Microsoft.Compute/virtualMachines/webserver1 --condition "avg Percentage CPU > 80" --window-size 5m --evaluation-frequency 1m
az monitor metrics alert create -n alertforWS2 -g rgsoutheastasia --description "alert" --scopes /subscriptions/0ddb8f2f-e4c9-4460-94f9-84af943ebabf/resourceGroups/rgsoutheastasia/providers/Microsoft.Compute/virtualMachines/webserver2 --condition "avg Percentage CPU > 80" --window-size 5m --evaluation-frequency 1m


##################################### CREATING AN NIC AND ASSOCIATED VM FOR JUMPPORT SERVER #####################################################

az network public-ip create --name jumpportPublicIP -g rgsoutheastasia --allocation-method Static 

az network nic create -n jumpportNIC -g rgsoutheastasia --subnet jumpportsubnet --vnet-name cliseavnet --location southeastasia --public-ip-address jumpportPublicIP


az vm create -n jumpportserver -g rgsoutheastasia --location southeastasia --nics jumpportNIC --size Standard_D1 --admin-password P@ssw0rd123! --admin-username mehervalluri --image MicrosoftWindowsServer:WindowsServer:2016-Datacenter:latest




################################################### CREATING RESOURCES IN EUS REGION ##################################################

###################################### CREATING A VIRTUAL NETWORK AND SUBNETS IN EUS REGION ############################################################


az group create --location eastus --name rgeastus

az network vnet create -g rgeastus -n clieusvnet --location eastus --address-prefixes 10.3.0.0/16 --subnet-name webserver11subnet --subnet-prefixes 10.3.1.0/24


############################### CREATING A RULE UNDER NSG AND ASSOCIATING WITH WEBSERVER11 SUBNET #########################################


az network nsg create --name nsgforwebserver11 --resource-group rgeastus --location eastus
az network nsg rule create -g rgeastus --nsg-name nsgforwebserver11 -n allowrdpforwebserver11 --priority 1001 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes 10.3.1.0/24 --destination-port-ranges 3389 --access Allow --protocol TCP --direction inbound --description 'allow_rdp_from_anyresource'
az network vnet subnet update -g rgeastus --vnet-name clieusvnet -n webserver11Subnet --network-security-group nsgforwebserver11


##################################### CREATING AN NIC AND ASSOCIATED VM FOR WEBSERVER11 #####################################################


az network public-ip create --name webserver11PublicIP -g rgeastus --allocation-method Static 
az network nic create -n webserver11NIC -g rgeastus --subnet webserver11subnet --vnet-name clieusvnet --location eastus --public-ip-address webserver11PublicIP

az vm create -n webserver11 -g rgeastus --location eastus --nics webserver11NIC --size Standard_B2ms --admin-password P@ssw0rd123! --admin-username mehervalluri --image MicrosoftWindowsServer:WindowsServer:2016-Datacenter:latest


######################################################## VNET PEERING #############################################################################

az network vnet peering create --name seatoeus --remote-vnet clieusvnet -g rgsoutheastasia --vnet-name cliseavnet --allow-vnet-access
az network vnet peering create --name eustosea --remote-vnet cliseavnet -g rgeastus --vnet-name clieusvnet --allow-vnet-access



################################################# CREATING STORAGE ACCOUNT FOR BOTH REGIONS ###############################################################

az storage account create --name cliseastoracc -g rgsoutheastasia --access-tier Cool --sku standard_GRS

az storage account create --name clieusstoracc -g rgeastus --access-tier Cool --sku standard_ZRS

az storage account keys list --account-name clieusstoracc


#################################################### USER CREATION AND RBAC #########################################################################

Az ad user create --display-name CLIuser1 --password P@ssw0rd123! --user-principal-name CLIuser1@mehervalluri5outlook.onmicrosoft.com
Az ad user create --display-name CLIuser2 --password P@ssw0rd123! --user-principal-name CLIuser2@mehervalluri5outlook.onmicrosoft.com

az account subscription list
az ad user show --id CLIuser1@mehervalluri5outlook.onmicrosoft.com
az ad user show --id CLIuser2@mehervalluri5outlook.onmicrosoft.com
az role assignment create --assignee "3cfc3e87-f685-4255-ad51-db3d929a4f0b"--role "virtual machine contributor" --subscription "0ddb8f2f-e4c9-4460-94f9-84af943ebabf"
az role assignment create --assignee "95181f7a-3195-4b62-b52a-15fd4efddc54"--role "virtual machine contributor" --scope "/subscriptions/0ddb8f2f-e4c9-4460-94f9-84af943ebabf/resourceGroups/rgeastus"