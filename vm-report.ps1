# vm-report.ps1 - Returns detailed report of vApp/VM replications

# Requires PowerCLI, PowerVCAV and must have connected sessions to both
# vCD (Connect-CIServer) and VCAV (Connect-VCAV) prior to running this script.

param(
    [string]$OrgName               # Optionally filter the results to a single vCloud Organization
)

Function ByteUnits($value) {
    if ($value -lt 1024) { return "$value B" }
    $value = $value / 1024
    if ($value -lt 1024) { return "$([math]::round($value,1)) KB" }
    $value = $value / 1024
    if ($value -lt 1024) { return "$([math]::round($value,1)) MB" }
    $value = $value / 1024
    return "$([math]::round($value,1)) GB"
}

Function LocalTime($timestamp) {
    return([timezone]::CurrentTimeZone.ToLocalTime((([System.DateTimeOffset]::FromUnixTimeMilliseconds($timestamp)).DateTime)).ToString())
}

$session = Invoke-VCAVQuery -QueryPath 'sessions'
if (! ($session.roles -contains 'ADMINISTRATORS')) {
    Write-Error("Storage report is only available to system administrators.")
    Exit
}

$sites = Invoke-VCAVQuery -QueryPath 'sites'
$local_site = ($sites | Where-Object { $_.isLocal -eq 'True' })
if (!$local_site) {
    Write-Error("Unable to determine the local site.")
    Exit
}

$diagnostics = Invoke-VCAVQuery -QueryPath 'diagnostics/health'
if ($diagnostics.managerHealth.offlineReplicators.Count -gt 0) {
    Write-Warning("One or more replicators are down. This can render the report incorrect.")
}

$unique_replications = @{}

$replications = Invoke-VCAVPagedQuery -QueryPath 'vm-replications'
foreach ($replication in $replications) {
    if ($OrgName) {
        if ($replication.destination.org -eq $OrgName) {
            $unique_replications.Add($replication.id,$replication)
        }
    } else { # No Organization specified, include all unique inbound replications:
        if ($replication.destination.org) {
            $unique_replications.Add($replication.id,$replication)
        }
    }
}

$reps = @()

foreach ($rep in $unique_replications.Values) {

    $instances = Invoke-VCAVQuery -QueryPath "vm-replications/$($rep.id)/instances"
    
    # Calculate average daily xfer size based on recorded instances and RPO
    # NOTE: This will give innaccurate results during the first 24hrs of
    # replication due to the generally large size of initial VM sync.
    $numinstances = $instances.Count
    $repsperday = (24 / ($rep.settings.rpo / 60))
    $totalxfer = ($instances | Measure-Object -Property transferBytes -Sum).Sum
    $avgxfer = $totalxfer / $numinstances
    $avgxferday = $avgxfer * $repsperday

    if ($rep.destinationState.currentRpoViolation -eq 0) {
         $rpoViolated = "No"
    } else {
         $rpoViolated = $rep.destinationState.currentRpoViolation.toString() + " mins"
    }

    $repObj = [PSCustomObject]@{
         Org            = $rep.destination.org
         Vdc            = $rep.destination.vdcname
         StoragePolicy  = $rep.storageProfileName
         vAppName       = $rep.source.vAppName
         VMName         = $rep.vmName
         RPO            = ($rep.settings.rpo).toString() + " mins"
         Paused         = $rep.isPaused
         RPOviolated    = $rpoViolated
         Quiesced       = $rep.settings.quiesced
         LastStatus     = LocalTime($rep.destinationState.latestInstance.timestamp).toString()
         LastXfer       = ByteUnits($rep.destinationState.latestInstance.transferBytes).toString()
         LastXferTime   = ($rep.destinationState.latestInstance.transferSeconds).toString() + " sec"
         DataConnection = $rep.dataConnectionState
         Migration      = $rep.isMigration
         overallHealth  = $rep.overallHealth
         Instances      = $numinstances
         AverageXfer    = (ByteUnits($avgxferday)).toString() + "/day"
         SpaceRequired  = ByteUnits($rep.destinationState.spaceRequirement)
    }
    $reps += $repObj
}
return $reps