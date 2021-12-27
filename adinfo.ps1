
<#
Title: adinfo.PS1
Author: Ahmed Bayoumy
Category: Utility Script
Description:
Generate HTML report for AD Info
#>

#HTML codes
$HTML = @"
<!doctype html>
<html lang="en">
<head>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-1BmE4kWBq78iYhFldvKuhfTAU6auU8tT94WrHftjDbrCEXSU1oBoqyl2QvZ6jIW3" crossorigin="anonymous">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>#Title#</title>
  <meta name="description" content="Active Directory HTML5 repoty.">
  <meta name="author" content="Ahmed M. Bayoumy">
</head>
<body>
  <!-- your content here... -->
  <div class="container-fluid">
    <div class="row d-flex justify-content-center text-center">
      #Title#
    </div>
    <div class="row">
      <div class="col text-center">#ForestName#
        <div class="row">#ForestRow1#</div>
        <div class="row">#ForestRow2#</div>
        <div class="row">#ForestRow3#</div>
      </div>
      <div class="col text-center">#DoaminName#
        <div class="row">#DomainRow1#</div>
        <div class="row">#DomainRow2#</div>
        <div class="row">#DomainRow3#</div>
        <div class="row">#DomainRow4#</div>
      </div>
    </div>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js" integrity="sha384-ka7Sk0Gln4gmtz2MlQnikT1wXgYsOg+OMhuP+IlRH9sENBO0LRn5q+8nbTov4+1p" crossorigin="anonymous"></script>
</body>
</html>
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
function Get-DCs {
    $allDCs = Get-ADDomainController -Filter *
    $allDCs | Select-Object hostname,site,operationMasterRoles,operatingsystem,operatingsystemversion,ipv4address

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

# $allDCs = (Get-ADForest).Domains | %{ Get-ADDomainController -Filter * -Server $_}
# $allDCs | Select-Object hostname,site,operationMasterRoles,operatingsystem,operatingsystemversion,ipv4address | ogv
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

$HTML.replace("#Title#",$($Domain.Name) Report")

$HTML.replace("#ForestName#",$Forest.Name)
$HTML.replace("#ForestRow1#","FL:$($Forest.ForestMode)")
$HTML.replace("#ForestRow2#","SchemaMaster:$($Forest.SchemaMaster)")
$HTML.replace("#ForestRow3#","DomainNamingMaster:$($Forest.DomainNamingMaster)")

$HTML.replace("#DoaminName#",$Domain.Name)
$HTML.replace("#ForestRow1#","FL:$($Domain.DomainMode)")
$HTML.replace("#DomainRow2#","SchemaMaster:$($Forest.SchemaMaster)")
$HTML.replace("#DomainRow2#","DomainNamingMaster:$($Forest.DomainNamingMaster)")

# $Forest_Domain_Info="<h2>Forest:$($Forest.Name) FL:$($Forest.ForestMode)</h2><h3>DomainNamingMaster:$($Forest.DomainNamingMaster)<br>SchemaMaster:$($Forest.SchemaMaster)</h3></h2>Domain:$($Domain.Name) FL:$($Domain.DomainMode) </h2>" 

#$Report = ConvertTo-HTML -Body "$ComputerName $OSinfo $ComputerModel $RAMInfo $DiscInfo " -Head $header -Title "$($Domain.DomainMode) Report" -PostContent "<p id='CreationDate'> Creation Date: $(Get-Date)</p>"
# ConvertTo-HTML -Body "$Forest_Domain_Info " -Head $header -Title "$($Domain.Name) Report" -PostContent "<h4> Created @ $(Get-Date)</h4>" | Out-File $ReportFile
ConvertTo-HTML $HTML | Out-File $ReportFile

Compress-Archive -Path $LogPath -DestinationPath $zipFile -Update

Write-Output "Reports saved to file $($zipFile)"
Start-Process (Split-Path -Path $LogPath)