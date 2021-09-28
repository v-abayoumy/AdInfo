
<#
Title: adinfo.PS1
Author: Ahmed Bayoumy
Category: Utility Script
Description:
Generate HTML report for AD Info
#>

#CSS codes
$header = @"
<style>
  div {
    line-height: normal;
  }

    body {
        color:#ffffff;
        background-color:#2E4057;
        line-height: normal;
    }

    h1 {

        font-family: Open Sans;
        color: #ffffff;
        font-size: 28px;
    }

    
    h2 {

        font-family: Open Sans;
        color: #ffffff;
        font-size: 16px;

    }

    h3 {

        font-family: Open Sans;
        color: #ffffff;
        font-size: 12px;
        line-height: normal;

    }

    h4 {

        font-family: Open Sans;
        color: #ffffff;
        font-size: 10px;
        line-height: normal;
    }

    a {

        font-family: Open Sans;
        color: #ffffff;
        font-size: 16px;
    }
    
    
   table {
		font-size: 12px;
		border: 0px; 
		font-family: Open Sans;
	} 
	
    td {
		padding: 4px;
		margin: 0px;
		border: 0;
	}
	
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #ffffff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
	}

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }
    


    #CreationDate {

        font-family: Open Sans;
        color: black;
        font-size: 12px;
        text-align: left;

    }


</style>
"@
function Export-AllGPOs {
    param (
        $path , $Forest
    )
    $GPOPath = "$($path)\GPO"
    New-Item $GPOPath -Type Directory -ErrorAction SilentlyContinue | Out-Null 
    $Forest.domains | ForEach-Object {
        Write-Host $_.Name
        Get-GPO -all -Domain $_  | ForEach-Object { 
            Write-Host $_.DisplayName
            Get-GPOReport  -Name $_.DisplayName -ReportType HTML -Path "$GPOPath\$($_.DisplayName).html"
        }
    }
}

if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Warning "Please run this script as adminidtrator."
    Exit
}

# check RSAT-AD-PowerShell
if( ! (get-module -list activedirectory)){
    Write-Warning "Please run this script on AD DC."
    Start-Process "https://docs.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools"
    Exit    
}
# $DomainRole = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty DomainRole
# Standalone Workstation (0)
# Member Workstation (1)
# Standalone Server (2)
# Member Server (3)
# Backup Domain Controller (4)
# Primary Domain Controller (5)



Import-Module activedirectory
Import-Module grouppolicy
$Forest=Get-ADForest
$Domain=Get-ADDomain
$LogPath = "$($PSScriptRoot)\AD-Info $((Get-Date).ToString('dd-MM-yyyy'))"
$zipFile = "$($LogPath).zip"
$HostName = $env:computername
$Now=$((Get-Date).ToString('dd-MM-yyyy hh-mm'))
$ReportFile = "$($LogPath)\$($Domain.Name)-$($Now).html"

If (!(Test-Path -Path $LogPath -ErrorAction SilentlyContinue )) {  New-Item $LogPath -Type Directory -ErrorAction SilentlyContinue | Out-Null }

Write-Output "Forest:$($Forest.Name) - $($Forest.ForestMode) `r`nDomain:$($Domain.Name) - $($Domain.DomainMode) "
Get-ADDefaultDomainPasswordPolicy > "$LogPath\PasswordPolicy.txt"
Netdom /query fsmo > "$($LogPath)\fsmo.txt"
Repadmin /showrepl * /csv > "$LogPath\showrepl-$($Now).csv"
Gpresult /f /h "$LogPath\GPResult-$($HostName)-$($Now).html"
Get-ADDomainController -Filter * | Select-Object Name, OperatingSystem, IPv4Address, Site > "$LogPath\dclist.txt"
# $Forest.domains | ForEach-Object { get-GPO -all -Domain $_ | Select-Object @{n='Domain Name';e={$_.DomainName}}, @{n='GPO Name';e={$_.DisplayName}}, @{n='GPO Guid';e={$_.Id}} , @{n='Gpo Status';e={$_.GpoStatus}} , @{n='Creation Time';e={$_.CreationTime}} , @{n='Modification Time';e={$_.ModificationTime}} } | Export-Csv "$LogPath\AllGPOsList.csv"
Export-AllGPOs $LogPath $Forest
Get-GPOReport -All  -ReportType HTML -Path "$LogPath\GPOReport-$($Now).html"

$Sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites           
$obj = @() 
foreach ($Site in $Sites) {            

 $obj += New-Object -Type PSObject -Property (            
  @{            
   "SiteName" = $site.Name     
   "SubNets" = $site.Subnets | ForEach-Object { $_ }            
   "Servers" = $Site.Servers | ForEach-Object { $_ }                    
  }            
 )            
}
$obj | Export-Csv "$LogPath\sites-$($Now).csv" -NoType 

$Forest_Domain_Info="<h2>Forest:$($Forest.Name) FL:$($Forest.ForestMode)</h2><h3>DomainNamingMaster:$($Forest.DomainNamingMaster)<br>SchemaMaster:$($Forest.SchemaMaster)</h3></h2>Domain:$($Domain.Name) FL:$($Domain.DomainMode) </h2>" 

#$Report = ConvertTo-HTML -Body "$ComputerName $OSinfo $ComputerModel $RAMInfo $DiscInfo " -Head $header -Title "$($Domain.DomainMode) Report" -PostContent "<p id='CreationDate'> Creation Date: $(Get-Date)</p>"
ConvertTo-HTML -Body "$Forest_Domain_Info " -Head $header -Title "$($Domain.Name) Report" -PostContent "<h4> Created @ $(Get-Date)</h4>" | Out-File $ReportFile

Compress-Archive -Path $LogPath -DestinationPath $zipFile -Update

Write-Output "Reports saved to file $($zipFile)"
Start-Process (Split-Path -Path $LogPath)