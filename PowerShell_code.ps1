#Connecting to Azaccount

Connect-AzAccount


#Creating two resource groups for each region
 

'southeastasia','eastus' | ForEach-Object { 

	$name = 'rg'+$_
	new-azresourcegroup -location $_ -name $name


######################### Creating virtualnetwork,subnets,nsg,nsgrules,VMs,load balancing configuration for SEA region ###############################



		if ($_.Equals('southeastasia')) {
 

 #################################### creating virtual network and subnets ########################################################

 			$webserverSubnet = New-AzVirtualNetworkSubnetConfig ` -Name webserverSubnet `
  					-AddressPrefix 10.2.1.0/24

 			$jumpportSubnet = New-AzVirtualNetworkSubnetConfig ` -Name jumpportSubnet `
  					-AddressPrefix 10.2.2.0/24


 			$pscsseavnet = New-AzVirtualNetwork `
  					-ResourceGroupName $name `
  					-Location $_ `
  					-Name pscssea-vnet `
  					-AddressPrefix 10.2.0.0/16 `
  					-Subnet $webserverSubnet, $jumpportSubnet


 
 ########################################### Creating NSG and setting rules against websubnet ###################################################


 			$allowrdpforws = @{
    						Name = 'allowrdpforws'
    						Description = 'allow_rdp_from_someip'
    						Protocol = 'TCP'
    						SourcePortRange = '*'
    						DestinationPortRange = '3389'
    						SourceAddressPrefix = '223.230.52.84'
    						DestinationAddressPrefix = $pscsseavnet.Subnets[0].AddressPrefix
    						Access = 'Allow'
    						Priority = '1001'
    						Direction = 'Inbound'
   					 }

    			$rule1 = New-AzNetworkSecurityRuleConfig @allowrdpforws

    			$nsgforws = New-AzNetworkSecurityGroup `
    					-Name 'nsgforws' `
    					-ResourceGroupName $name `
    					-Location $_ `
    					-SecurityRules $rule1


#################################### Now that nsg and a rule is created, associating the nsg with the webserver subnet ##############################


			$webserversubnetconfig = Set-AzVirtualNetworkSubnetConfig `
   						-Name webserverSubnet `
   						-VirtualNetwork $pscsseavnet `
   						-AddressPrefix $pscsseavnet.Subnets[0].AddressPrefix `
   						-NetworkSecurityGroup $nsgforws

			Set-AzVirtualNetwork -VirtualNetwork $pscsseavnet

		
 ########################################### Creating NSG and setting rules against jumportsubnet ###################################################


			$allowrdpforjumpport = @{
    
    						Name = 'allowrdpforjumpport'
    						Description = 'allow_rdp_from_someip'
    						Protocol = 'TCP'
    						SourcePortRange = '*'
    						DestinationPortRange = '3389'
  						SourceAddressPrefix = '223.230.52.84'
    						DestinationAddressPrefix = $pscsseavnet.Subnets[1].AddressPrefix
    						Access = 'Allow'
    						Priority = '1001'
    						Direction = 'Inbound'

  					  }


			$rule2 = New-AzNetworkSecurityRuleConfig @allowrdpforjumpport

			$nsgforjumpport = New-AzNetworkSecurityGroup `
    					  -Name 'nsgforjumpport' `
    					  -ResourceGroupName $name `
    					  -Location $_ `
    					  -SecurityRules $rule2


#################################### Now that nsg and a rule is created, associating the nsg with the webserver subnet ##############################


			$jumpportsubnetconfig = Set-AzVirtualNetworkSubnetConfig `
   						-Name jumpportSubnet `
   						-VirtualNetwork $pscsseavnet `
   						-AddressPrefix $pscsseavnet.Subnets[1].AddressPrefix `
   						-NetworkSecurityGroup $nsgforjumpport

			Set-AzVirtualNetwork -VirtualNetwork $pscsseavnet


############################################### CREATING AND CONFIGURING A LOAD BALANCER ####################################################

			$lbpublicIP = New-AzPublicIpAddress `
  					-ResourceGroupName $name `
  					-Location $_ `
  					-AllocationMethod "Static" `
  					-Name "lbPublicIP"

			$loadbalancerfrontend = New-AzLoadBalancerFrontendIpConfig `
  						-Name "Loadbalancerfrontend" `
  						-PublicIpAddress $lbpublicIP

			$backendPool = New-AzLoadBalancerBackendAddressPoolConfig `
  					-Name "BackEndPool"


			$lbrule = New-AzLoadBalancerRuleConfig `
    					-Name 'lbrule' `
    					-Protocol 'TCP' `
    					-FrontendPort '80' `
    					-BackendPort '80' `
    					-IdleTimeoutInMinutes '15' `
    					-FrontendIpConfiguration $loadbalancerfrontend `
    					-BackendAddressPool $backendPool

			$RDPinboundNATrule = New-AzLoadBalancerInboundNatRuleConfig `
    						-Name "RDPInboundNATrule" `
						    -FrontendIPConfiguration $loadbalancerfrontend `
						    -Protocol "TCP" `
						    -FrontendPort 3389 `
						    -BackendPort 3389

            
 			$lbhealthprobe = New-AzLoadBalancerProbeConfig `
  					-Name "lbhealthprobe" `
  					-Protocol TCP `
  					-Port 80 `
  					-IntervalInSeconds 15 `
  					-ProbeCount 2

			$lbsea = New-AzLoadBalancer `
  					-ResourceGroupName $name `
  					-Name "lbsea" `
  					-Location $_ `
  					-FrontendIpConfiguration $loadbalancerfrontend `
  					-BackendAddressPool $backendPool `
                    -probe $lbhealthprobe `
  					-LoadBalancingRule $lbrule `
  					-InboundNATrule $RDPinboundNATrule `
  					-SKU "Basic"


 ##################################### creating an availability-set before creating VM ############################################################

  			$wsavailabilityset = New-AzAvailabilitySet `
   						-Location $_ `
   						-Name wsavailabilityset `
   						-ResourceGroupName $name `
   						-Sku aligned `
   						-PlatformFaultDomainCount 2 `
   						-PlatformUpdateDomainCount 2

####################################### for-loop which creates WEBSERVER NIC,VMs,backup and alerts at once ##########################################

  			for ($i=1; $i -le 2; $i++)

				{

  					$networkinterface =  New-AzNetworkInterface `
     								-ResourceGroupName $name `
     								-Name webserverNIC$i `
     								-Location $_ `
     								-Subnet $pscsseavnet.Subnets[0] `
     								-LoadBalancerBackendAddressPool $lbsea.BackendAddressPools[0] `
     								-LoadbalancerInboundNatRule $RDPinboundNATrule
     


############################################## CREATING A VIRTUAL MACHINE - WEB SERVERS #############################################################

							$cred = get-credential
                            $vmsize = Read-Host "Enter the VMSize for webserver (Example: standard_D1, standard_ds2_v3)"

							$vmsz = @{
    
								VMName = "webserver$i"
    								VMSize = $vmsize 
    								availabilitysetID = $wsavailabilityset.Id
								
								}

							$vmos = @{
    								
								ComputerName = "webserver$i"
    								Credential = $cred

								}

							$vmimage = @{
    
								PublisherName = 'MicrosoftWindowsServer'
    								Offer = 'WindowsServer'
    								Skus = '2016-Datacenter'
    								Version = 'latest'    
								
								}

							$vmConfig = New-AzVMConfig @vmsz `
   									 | Set-AzVMOperatingSystem @vmos -Windows `
   									 | Set-AzVMSourceImage @vmimage `
    								 | Add-AzVMNetworkInterface -Id $networkinterface.Id


							$vm = @{
    								
								ResourceGroupName = $name
    								Location = $_
    								VM = $vmConfig
                                   }
	
						New-AzVM @vm

            ########################################### Installing IIS in webservers ############################################################



Set-AzVMExtension `
     -ResourceGroupName $name `
     -ExtensionName "IIS" `
     -VMName webserver$i `
     -Publisher Microsoft.Compute `
     -ExtensionType CustomScriptExtension `
     -TypeHandlerVersion 1.8 `
     -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' `
     -Location $_
     

		############################## Creating and Configuring BACKUP policy for webservers ##################################



Register-AzResourceProvider -ProviderNamespace "Microsoft.RecoveryServices"

New-AzRecoveryServicesVault `
    -ResourceGroupName $name `
    -Name "RecoveryServicesVault" `
    -Location $_ | Set-AzRecoveryServicesBackupProperty -BackupStorageRedundancy LocallyRedundant

Get-AzRecoveryServicesVault `
    -Name "RecoveryServicesVault" | Set-AzRecoveryServicesVaultContext


$SchPol = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM" 
$SchPol.ScheduleRunTimes.Clear()
$Time = Get-Date
$SchPol.ScheduleRunFrequency.Clear
$Time1 = Get-Date -Year $Time.Year -Month $Time.Month -Day $Time.Day -Hour $Time.Hour -Minute 0 -Second 0 -Millisecond 0
$Time1 = $Time1.ToUniversalTime()
$SchPol.ScheduleRunTimes.Add($Time1)
$SchPol.ScheduleRunFrequency="Daily"


$RetPol = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM" 
$RetPol.IsDailyScheduleEnabled=$true
$RetPol.IsWeeklyScheduleEnabled=$false
$RetPol.IsMonthlyScheduleEnabled=$true
$RetPol.IsYearlyScheduleEnabled=$false
$RetPol.DailySchedule.DurationCountInDays = 90


$webserverVMpolicy = New-AzRecoveryServicesBackupProtectionPolicy `
                     -Name "webserverVMpolicy" `
                     -WorkloadType AzureVM `
                     -RetentionPolicy $RetPol `
                     -SchedulePolicy $SchPol

Enable-AzRecoveryServicesBackupProtection `
    -ResourceGroupName $name `
    -Name webserver$i `
    -Policy $webserverVMpolicy



	######################################## Creating and Configuring CPU alert for webservers ###################################


$VMresourceID = (Get-Azresource -Name webserver$i).Id

$condition = New-AzMetricAlertRuleV2Criteria -MetricName "Percentage CPU" -TimeAggregation Average -Operator GreaterThan -Threshold 80

Add-AzMetricAlertRuleV2 `
-Name 'CPUalertforVM' `
-ResourceGroupName $name `
-WindowSize 0:5 `
-Frequency 0:5 `
-TargetResourceid $VMresourceID[1] `
-Description "Gives a warning if cpu usage is greater than 80" `
-Severity 2 `
-Condition $condition



			
            	} # end for for-loop which creates NIC,VMs,backup and alerts at once


			 ################################## creating network interface for jumpportserver ########################################

		            $jumpportpublicIP = New-AzPublicIpAddress `
  					            -ResourceGroupName $name `
  					            -Location $_ `
  					            -AllocationMethod "Static" `
  					            -Name "jumpportPublicIP"


  					$jumpportinterface = New-AzNetworkInterface `
     								-ResourceGroupName $name `
     								-Name jumpportNIC `
     								-Location $_ `
     								-Subnet $pscsseavnet.Subnets[1] `
                                    -PublicIpAddress $jumpportpublicIP
     						

    			###################### CREATING A VIRTUAL MACHINE - JUMP PORT SERVER ######################################


     						$cred = get-credential
                            $vmsize = Read-Host "Enter the VMSize for jumpport (Example: standard_D1, standard_ds2_v3)"

							$vmsz = @{
    
								VMName = "jumpportserver"
    								VMSize = $vmsize 
								
								}

							$vmos = @{
    								
								ComputerName = "jumportserver"
    								Credential = $cred

								}

							$vmimage = @{
    
								PublisherName = 'MicrosoftWindowsServer'
    								Offer = 'WindowsServer'
    								Skus = '2016-Datacenter'
    								Version = 'latest'    
								
								}

							$vmConfig = New-AzVMConfig @vmsz `
   									 | Set-AzVMOperatingSystem @vmos -Windows `
   									 | Set-AzVMSourceImage @vmimage `
    								 | Add-AzVMNetworkInterface -Id $jumportinterface.Id


							$vm = @{
    								
								ResourceGroupName = $name
    								Location = $_
    								VM = $vmConfig
                                   }
	
							New-AzVM @vm

		

 		############################## creating storage account for SEA region ##############################################

 $pscsseastorageacc = New-AzStorageAccount `
                    -ResourceGroupName $name `
                    -Location $_ `
                    -SkuName Standard_GRS `
                    -Name 'pscsseastorageacc'

 $seastoragekeys = Get-AzStorageAccountKey -ResourceGroupName $name -Name $pscsseastorageacc.StorageAccountName


			} # end for if location = southeastasia condition 




 	################################## Creating virtualnetwork,subnets,nsg,nsgrules,VMs for SEA region ####################################

 else  

 	{


 		$webserver11Subnet = New-AzVirtualNetworkSubnetConfig ` -Name webserver11Subnet `
  				-AddressPrefix 10.3.1.0/24


 		$pscseusvnet = New-AzVirtualNetwork `
  				-ResourceGroupName $name `
  				-Location $_ `
  				-Name pscseus-vnet `
 				-AddressPrefix 10.3.0.0/16 `
  				-Subnet $webserver11Subnet

        $allowrdpforwebserver11 = @{
    
    						    Name = 'allowrdpforwebserver11'
    						    Description = 'allow_rdp_from_anyresource'
    						    Protocol = 'TCP'
    						    SourcePortRange = '*'
    						    DestinationPortRange = '3389'
  						        SourceAddressPrefix = '*'
    						    DestinationAddressPrefix = $pscseusvnet.Subnets[0].AddressPrefix
    						    Access = 'Allow'
    						    Priority = '1001'
    						    Direction = 'Inbound'

  					             }


			$rule3 = New-AzNetworkSecurityRuleConfig @allowrdpforwebserver11

			$nsgforwebserver11 = New-AzNetworkSecurityGroup `
    					  -Name 'nsgforwebserver11' `
    					  -ResourceGroupName $name `
    					  -Location $_ `
    					  -SecurityRules $rule3

   ######################### Now that nsg and a rule is created, associating the nsg with the webserver11subnet ################################


			$webserver11subnetconfig = Set-AzVirtualNetworkSubnetConfig `
   						-Name webserver11Subnet `
   						-VirtualNetwork $pscseusvnet `
   						-AddressPrefix $pscseusvnet.Subnets[0].AddressPrefix `
   						-NetworkSecurityGroup $nsgforwebserver11

			Set-AzVirtualNetwork -VirtualNetwork $pscseusvnet


	############################## creating network interface for Webserver11 ################################################


		            $webserver11publicIP = New-AzPublicIpAddress `
  					            -ResourceGroupName $name `
  					            -Location $_ `
  					            -AllocationMethod "Static" `
  					            -Name "webserver11PublicIP"


  					$webserver11interface = New-AzNetworkInterface `
     								-ResourceGroupName $name `
     								-Name webserver11NIC `
     								-Location $_ `
     								-Subnet $pscseusvnet.Subnets[0] `
                                    -PublicIpAddress $webserver11publicIP
     						

    ############################################### CREATING A VIRTUAL MACHINE - WEBSERVER11 ######################################


     						$cred = get-credential
                            $vmsize = Read-Host "Enter the VMSize for WEBSERVER11 (Example: Standard_B2ms, standard_ds2_v2)"

							$vmsz = @{
    
								VMName = "webserver11"
    								VMSize = $vmsize 
								
								}

							$vmos = @{
    								
								ComputerName = "webserver11"
    								Credential = $cred

								}

							$vmimage = @{
    
								PublisherName = 'MicrosoftWindowsServer'
    								Offer = 'WindowsServer'
    								Skus = '2016-Datacenter'
    								Version = 'latest'    
								
								}

							$vmConfig = New-AzVMConfig @vmsz `
   									 | Set-AzVMOperatingSystem @vmos -Windows `
   									 | Set-AzVMSourceImage @vmimage `
    								 | Add-AzVMNetworkInterface -Id $webserver11interface.Id


							$vm = @{
    								
								ResourceGroupName = $name
    								Location = $_
    								VM = $vmConfig
                                   }
	
							New-AzVM @vm


 			################################## creating storage account for SEA region #######################################


 $pscseusstorageacc = New-AzStorageAccount `
                    -ResourceGroupName $name `
                    -Location $_ `
                    -SkuName Standard_ZRS `
                    -Name 'pscseusstorageacc'

$eusstoragekeys = Get-AzStorageAccountKey -ResourceGroupName $name -Name $pscseusstorageacc.StorageAccountName


	 } # end for if location = eastus condition 

  }  # ending foreach loop


  			################################# PEERING THE VIRTUAL NETWORKS ########################################
  
  
  Write-host "Peering the Virtual Networks"


  Add-AzVirtualNetworkPeering `
  -Name pscsseavnet_to_pscseusvnet `
  -VirtualNetwork $pscsseavnet `
  -RemoteVirtualNetworkId $pscseusvnet.Id


    Add-AzVirtualNetworkPeering `
  -Name pscseusvnet_to_pscsseavnet `
  -VirtualNetwork $pscseusvnet `
  -RemoteVirtualNetworkId $pscsseavnet.Id

 Write-host "Virtual Networks are Connected"


 	 ###################################### CREATING USER ACCOUNTS AND GIVING ACCESS ########################################

 Install-module AzureAD
Connect-AzureAD -TenantId e50404b4-45b1-4e2a-845d-1f2385fdcf7f


$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = "P@ssw0rd@1"
New-AzureADUser -DisplayName "PSuser1" -PasswordProfile $PasswordProfile -UserPrincipalName "PSuser1@mehervalluri5outlook.onmicrosoft.com" -AccountEnabled $true -verbose -mailnickname PSuser1


$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = "P@ssw0rd@1"
New-AzureADUser -DisplayName "PSuser2" -PasswordProfile $PasswordProfile -UserPrincipalName "PSuser2@mehervalluri5outlook.onmicrosoft.com" -AccountEnabled $true -verbose -mailnickname PSuser1

get-azaduser -searchstring "PSuser1"
New-AzRoleAssignment -ObjectId cb9df287-1ea2-4b04-9b9a-5667f67a1748 -RoleDefinitionName "Backup Contributor"  -ResourceGroupName rgeastus


get-azaduser -searchstring "PSuser2"
get-azsubscription
New-AzRoleAssignment -ObjectId 0876ec58-0e90-407e-ba23-f17469aae884 -RoleDefinitionName "Virtual Machine Contributor" -scope "/subscriptions/0ddb8f2f-e4c9-4460-94f9-84af943ebabf/"
