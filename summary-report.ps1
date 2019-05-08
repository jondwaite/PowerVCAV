# summary-report.ps1 - Returns summary of number of replications per Org by type

# Requires PowerCLI, PowerVCAV and must have connected sessions to both
# vCD (Connect-CIServer) and VCAV (Connect-VCAV) prior to running this script.

$vcloud_sites = Invoke-VCAVQuery -QueryPath 'sites'
$local_site = ($vcloud_sites | Where-Object { $_.isLocal -eq 'True' })

if (!$local_site) {
    Write-Error("Unable to determine the local site."); Break
}

$vcloud_sites = ($vcloud_sites | Where-Object { $_.site -ne $local_site.site })
$vc_sites = Invoke-VCAVQuery -QueryPath 'vc-sites'

$replications = Invoke-VCAVPagedQuery -QueryPath 'vapp-replications'

$orgsummary = @()

$org_list = Invoke-VCAVPagedQuery -QueryPath 'inventory/orgs'
foreach ($org in $org_list) {
    $orgtotals = @{ 
        c2cpvapp = 0; v2cpvapp = 0; c2vpvapp = 0; c2cmvapp = 0; v2cmvapp = 0; c2vmvapp = 0; Totalvapp = 0 
        c2cpvm   = 0; v2cpvm   = 0; c2vpvm   = 0; c2cmvm   = 0; v2cmvm   = 0; c2vmvm   = 0; Totalvm   = 0
    }
    $orgreps = [array]($replications | Where-Object { ($_.source.org -eq $org.Name) -or ($_.destination.org -eq $org.Name) })
    
    foreach ($orgrep in $orgreps) {

        $numvms = $orgrep.vmreplications.Count

        if ($vc_sites.site -contains $orgrep.source.site) { # Source is vCenter
            if ($orgrep.isMigration -eq 'True') { 
                $orgtotals.v2cmvapp += 1
                $orgtotals.v2cmvm   += $numvms
            } else {
                $orgtotals.v2cpvapp += 1
                $orgtotals.v2cpvm   += $numvms
            }
        } elseif ($vc_sites.site -contains $orgrep.destination.site) { # Destination is vCenter
            if ($orgrep.isMigration -eq 'True') {
                $orgtotals.c2vmvapp += 1
                $orgtotals.c2vmvm   += $numvms
            } else {
                $orgtotals.c2vpvapp += 1
                $orgtotals.c2vpvm += $numvms 
            }
        } else { # Source and Destination are Cloud
            if ($orgrep.isMigration -eq 'True') {
                $orgtotals.c2cmvapp += 1
                $orgtotals.c2cmvm   += $numvms
            } else { 
                $orgtotals.c2cpvapp += 1
                $orgtotals.c2cpvm   += $numvms
            }
        }
    }        

    $orgobj = [PSCustomObject]@{
        Org = $org.Name
        C2CProt_vApp = ($orgtotals.c2cpvapp)
        C2CProt_VM   = ($orgtotals.c2cpvm)
        C2CMig_vApp  = ($orgtotals.c2cmvapp)
        C2CMig_VM    = ($orgtotals.c2cmvm)
        V2CProt_vApp = ($orgtotals.v2cpvapp)
        V2CProt_VM   = ($orgtotals.v2cpvm)
        V2CMig_vApp  = ($orgtotals.v2cmvapp)
        V2CMig_VM    = ($orgtotals.v2cmvm)
        C2VProt_vApp = ($orgtotals.c2vpvapp)
        C2vProt_VM   = ($orgtotals.c2vpvm)
        C2VMig_vApp  = ($orgtotals.c2vmvapp)
        C2VMig_VM    = ($orgtotals.c2vmvm)
        Total_vApp   = ($orgtotals.c2cpvapp + $orgtotals.c2cmvapp + $orgtotals.v2cpvapp + $orgtotals.v2cmvapp + $orgtotals.c2vpvapp + $orgtotals.c2vmvapp)
        Total_VM     = ($orgtotals.c2cpvm   + $orgtotals.c2cmvm   + $orgtotals.v2cpvm   + $orgtotals.v2cmvm   + $orgtotals.c2vpvm   + $orgtotals.c2vmvm)
    }
    $orgsummary += $orgobj
}

$orgsummary