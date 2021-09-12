
<#
Title: adinfo.PS1
Author: Ahmed Bayoumy
Category: Utility Script
Description:
Generate HTML report for AD
#>

#CSS codes
$header = @"
<style>
    body {
        color:#fff;background-color:#16a085;
    }

    h1 {

        font-family: Arial, Helvetica, sans-serif;
        color: #fff;
        font-size: 28px;
    }

    
    h2 {

        font-family: Arial, Helvetica, sans-serif;
        color: #fff;
        font-size: 16px;

    }

    a {

        font-family: Arial, Helvetica, sans-serif;
        color: #fff;
        font-size: 16px;

    }
    
    
   table {
		font-size: 12px;
		border: 0px; 
		font-family: Arial, Helvetica, sans-serif;
	} 
	
    td {
		padding: 4px;
		margin: 0px;
		border: 0;
	}
	
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
	}

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }
    


    #CreationDate {

        font-family: Arial, Helvetica, sans-serif;
        color: black;
        font-size: 12px;
        text-align: left;

    }


</style>
"@


if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Warning "Please run this script as adminidtrator."
    Exit
}

#//todo check and load RSAT-AD-PowerShell
if( ! (get-module -list activedirectory)){
    Write-Warning "Please run this script on AD DC or on Computer with RSAT installed."
    Start-Process "https://docs.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools"
    Exit    
}

Import-Module activedirectory
Import-Module grouppolicy
$path = "c:\MS-Log $((Get-Date).ToString('dd-MM-yyyy'))"
$HostName = [System.Net.Dns]::GetHostName()
$Now=$((Get-Date).ToString('dd-MM-yyyy hh-mm'))
If (!(Test-Path -Path $path -ErrorAction SilentlyContinue )) {  New-Item $path -Type Directory -ErrorAction SilentlyContinue | Out-Null }

$DFL=(Get-ADDomain).DomainMode
$FFL=(Get-ADForest).ForestMode
$Forest=Get-ADForest
$Domain=Get-ADDomain
Write-Output "Forest:$($Forest.Name) $($Forest.Domains)"
Get-ADDomain | fl Name, DomainMode > "$path\DFL.txt"
Get-ADForest | fl Name, ForestMode > "$path\FFL.txt"
Netdom /query fsmo > "$($path)\fsmo.txt"
Repadmin /showrepl * /csv > "$path\showrepl-$($Now).csv"
Gpresult /h "$path\GPResult-$($HostName)-$($Now).html"
Get-ADDomainController -Filter * | Select-Object Name, OperatingSystem, IPv4Address, Site > "$path\dclist.txt"
(get-ADForest).domains | ForEach-Object { get-GPO -all -Domain $_ | Select-Object @{n='Domain Name';e={$_.DomainName}}, @{n='GPO Name';e={$_.DisplayName}}, @{n='GPO Guid';e={$_.Id}} , @{n='Gpo Status';e={$_.GpoStatus}} , @{n='Creation Time';e={$_.CreationTime}} , @{n='Modification Time';e={$_.ModificationTime}} } | Export-Csv "$path\AllGPOsList.csv"
Get-GPOReport -All  -ReportType HTML -Path "$path\GPOReport-$($Now).html"

$Sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites           
$obj = @() 
foreach ($Site in $Sites) {            

 $obj += New-Object -Type PSObject -Property (            
  @{            
   "SiteName"  = $site.Name     
   "SubNets" = $site.Subnets | % { $_ }            
   "Servers" = $Site.Servers | % { $_ }                    
  }            
 )            
}
$obj | Export-Csv "$path\sites-$($Now).csv" -NoType 



Compress-Archive -Path $path -DestinationPath "$($path).zip" -Update