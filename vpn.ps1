$ScriptVersion = "0.1.0"

<#
 Licensed to Vadym Klymenko under one or more contributor license agreements.
 See the NOTICE file distributed with this work for additional information regarding copyright ownership.
 Vadym Klymenko licenses this file to You under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
#>

<#
.SYNOPSIS
    
.DESCRIPTION
    
.NOTES
    Usage:

    Invoke-WebRequest -Uri ftp://mikrotikFtpLogin:mikrotikFtpPassword@serialnumber.sn.mynetname.net/vpn.ps1 | iex
#>

###########################################################################
#
# Configurable settings

$ProfileName = "companyAutoVPN"
$vpnServer = "serialnumber.sn.mynetname.net"
$vpnServers = "primary.vpn.company.com,secondary.vpn.company.com"

$ftpUsername = "mikrotikFtpLogin"
$ftpPassword = "mikrotikFtpPassword"
$remoteNetwork = "192.168.88.0"
$remoteMasklen = 24
$TrustedNetworkDetection = "company.local"

# End of configurable settings. 
# The user does not need to pay attention to what follows below this block.
#
###########################################################################

# Указываем URL скрипта
$baseUrl = "ftp://${ftpUsername}:${ftpPassword}@${vpnServer}"

# Загружаем скрипт с FTP и сохраняем локально
$scriptFile = "vpn.ps1" 
Invoke-WebRequest -Uri $baseUrl/$scriptFile -UseBasicParsing -OutFile $env:TEMP\$scriptFile

#$scriptFile = "vpn.AfterReboot.ps1"
#Invoke-WebRequest -Uri $baseUrl/$scriptFile -UseBasicParsing -OutFile $env:TEMP\$scriptFile

# Проверяем права администратора
$adminCheck = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$adminRole = [System.Security.Principal.WindowsPrincipal]::new($adminCheck)
$isAdmin = $adminRole.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Скрипт не запущен от имени администратора. Перезапускаем..."
    
    # Запускаем новый PowerShell с правами администратора, загружая скрипт из файла
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Verb RunAs

    # Завершаем текущий процесс
    exit
}
Write-Host "Скрипт запущен с правами администратора!"
# --- Здесь идет основной код VPN-настройки ---
Invoke-WebRequest -Uri ftp://${ftpUsername}:${ftpPassword}@${vpnServer}/${vpnServer}.CA.crt -UseBasicParsing -OutFile $env:TEMP\${vpnServer}.CA.crt -ErrorAction Stop
Import-Certificate -FilePath  $env:TEMP\${vpnServer}.CA.crt -CertStoreLocation Cert:\LocalMachine\Root
# Указываем путь для сохранения XML
$xmlFilePath = "$env:TEMP\vpn.xml"
# Скачиваем xml файл
# Invoke-WebRequest -Uri ftp://${ftpUsername}:${ftpPassword}@${vpnServer}/vpn.xml -UseBasicParsing -OutFile $xmlFilePath -ErrorAction Stop

# Создаём объект PowerShell, который будет преобразован в XML
# Создаём объект XML
$xml = New-Object System.Xml.XmlDocument

# Создаём корневой элемент
$root = $xml.CreateElement("VPNProfile")
$xml.AppendChild($root)

# --- Создаём `NativeProfile` ---
$nativeProfile = $xml.CreateElement("NativeProfile")

$servers = $xml.CreateElement("Servers")
$servers.InnerText = "$vpnServer,$vpnServers"
$nativeProfile.AppendChild($servers)

$protocol = $xml.CreateElement("NativeProtocolType")
$protocol.InnerText = "Automatic"
$nativeProfile.AppendChild($protocol)

$auth = $xml.CreateElement("Authentication")
$userMethod = $xml.CreateElement("UserMethod")
$userMethod.InnerText = "MSChapv2"
$auth.AppendChild($userMethod)
$nativeProfile.AppendChild($auth)

$routing = $xml.CreateElement("RoutingPolicyType")
$routing.InnerText = "SplitTunnel"
$nativeProfile.AppendChild($routing)

$disableRoute = $xml.CreateElement("DisableClassBasedDefaultRoute")
$disableRoute.InnerText = "true"
$nativeProfile.AppendChild($disableRoute)

$root.AppendChild($nativeProfile)

# --- Создаём `Route` ---
$route = $xml.CreateElement("Route")

$address = $xml.CreateElement("Address")
$address.InnerText = "10.66.0.0"
$route.AppendChild($address)

$prefixSize = $xml.CreateElement("PrefixSize")
$prefixSize.InnerText = "16"
$route.AppendChild($prefixSize)

$root.AppendChild($route)

# --- Создаём `AppTrigger` ---
$appTrigger = $xml.CreateElement("AppTrigger")
$app = $xml.CreateElement("App")

$appId = $xml.CreateElement("Id")
$appId.InnerText = "%windir%\system32\mstsc.exe"

$app.AppendChild($appId)
$appTrigger.AppendChild($app)
$root.AppendChild($appTrigger)

# --- Остальные параметры ---
$alwaysOn = $xml.CreateElement("AlwaysOn")
$alwaysOn.InnerText = "true"
$root.AppendChild($alwaysOn)

$trustedNet = $xml.CreateElement("TrustedNetworkDetection")
$trustedNet.InnerText = "tt.pivo.local"
$root.AppendChild($trustedNet)

$deviceTunnel = $xml.CreateElement("DeviceTunnel")
$deviceTunnel.InnerText = "false"
$root.AppendChild($deviceTunnel)

$registerDNS = $xml.CreateElement("RegisterDNS")
$registerDNS.InnerText = "true"
$root.AppendChild($registerDNS)

# --- Сохраняем XML в файл ---
$xml.Save($xmlFilePath)

Write-Host "XML-файл успешно создан: $xmlFilePath"
############
$ProfileXML = Get-Content $xmlFilePath
$ProfileNameEscaped = $ProfileName -replace ' ', '%20'
$ProfileXML = $ProfileXML -replace '<', '&lt;'
$ProfileXML = $ProfileXML -replace '>', '&gt;'
$ProfileXML = $ProfileXML -replace '"', '&quot;'
$nodeCSPURI = './Vendor/MSFT/VPNv2'
$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_VPNv2_01"
$session = New-CimSession
try
{
    $newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", "$nodeCSPURI", 'String', 'Key')
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", "$ProfileNameEscaped", 'String', 'Key')
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ProfileXML", "$ProfileXML", 'String', 'Property')
    $newInstance.CimInstanceProperties.Add($property)
    $session.CreateInstance($namespaceName, $newInstance)
    $Message = "Created $ProfileName profile."
    Write-Host "$Message"
}
catch [Exception]
{
    $Message = "Unable to create $ProfileName profile: $_"
    Write-Host "$Message"
    Read-Host "Нажмите Enter to exit"
    exit
}
Set-VpnConnection -Name $ProfileName -L2tpPsk "L2TPServer" -PassThru -RememberCredential $True

#Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
#Install-Module -Name VPNCredentialsHelper -Force 
#Import-Module VPNCredentialsHelper -Force
# Set-VpnConnectionUsernamePassword -connectionname "Norma-Trade Auto" -username "USERNAME" -password "PASSWORD"
#Set-NetConnectionProfile -InterfaceAlias $ProfileName -NetworkCategory Private

Read-Host "Press Enter to reboot"

$scriptToRun = "$env:TEMP\vpn.AfterReboot.ps1"
$taskName = "RunAfterReboot"

# Создать задачу, которая выполнится один раз после перезагрузки
schtasks /Create /TN $taskName /TR "powershell.exe -ExecutionPolicy Bypass -File `"$scriptToRun`"" /SC ONSTART /RL HIGHEST /F

Read-Host "Press Enter to reboot"
# Перезагрузка
Restart-Computer -Force
