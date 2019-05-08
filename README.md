# PowerVCAV

VMware vCloud Availability (vCAV) 3.0 PowerShell cmdlets to assist working with the vCAV API

This module provides cmdlets to make it easier to work with the new API available in vCloud Availability 3.0. Connections to the API are persisted in session variables allowing multiple queries to use the same connection and save needing to authenticate each API interaction.

The table below shows the cmdlets available in this release with a brief description of their functions. The following sections detail the usage of each cmdlet.

cmdlet Name | Function
----------- | --------
Connect-VCAV | Uses session from an existing vCloud Director PowerCLI session (Connect-CIServer) to authenticate to the vCloud Availability API.
Connect-VCAVExtend | Uses session from an existing vCloud Director PowerCLI session to extend vCloud Availability connect to additional sites.
Disconnect-VCAV | Cleanly logout from a vCloud Availability session and remove session state.
Get-VCAVToken | Retrieve the X-VCAV-Auth token from a VCAV API connection for use outside of these cmdlets.
Invoke-VCAVQuery | Submit an HTTPS request against the vCloud Availability API, supports all HTML methods.
Invoke-VCAVPagedQuery | Submit an HTTPS request against the vCloud Availability API for Get methods that use pages where the returned data could contain a large number of objects.

Also provided in this repository are 2 example scripts:

Script Name | Function
----------- | --------
summary-report.ps1 | Shows the extraction of summary statistics from vCloud Availability which show the number of vApps/VMs being protected or migrated split by replication type (vSphere to Cloud, Cloud-to-Cloud or Cloud-to-vSphere) broken down by vCloud Director organization.
vm-report.ps1 | Shows detailed replication statistics for each replicated VM, and attempts to calculate an average data-rate change per day based on the recorded sizes of VM replications over the past 24 hours.

## Installation

This module has been uploaded to PowerShell Gallery and can be installed for the current user by:

```PowerShell
Install-Module PowerVCAV -Scope CurrentUser
```

or globally using:
```PowerShell
Install-Module PowerVCAV
```

It can also be downloaded and added to the current PowerShell session by:

```PowerShell
Import-Module .\PowerVCAV.psm1
```

## Connect-VCAV

This function establishes a connection to the vCloud Availability API and persists this in session variables within the PowerShell session. Note that sessions will time-out if not used for a period of time (I believe this to be 30 minutes currently). If this happens the session can be disconnected using Disconnect-VCAV and re-established.

Parameters:

Parameter | Type | Default | Required | Description
--------- | ---- | ------- | -------- | -----------
VCAVHost  | string | - | True  | The IP address or DNS hostname of the vCloud Availability server to connect to (generally the 'vApp Replication Manager' node).
VCDHost   | string | - | False | The IP address or DNS hostname of the vCloud Director API server which has already been connected using PowerCLI Connect-CIServer. If currently connected to multiple vCloud Director API endpoints then this parameter must be specified for Connect-VCAV. Note that the host name used in Connect-VCAV must exactly match the host name used in Connect-CIServer so that the corresponding session can be located.

Output:

A console message indicating whether the connection attempt was successful or not. The connection is persisted using PowerShell session variables for the current PowerShell session.

Example:

```PowerShell
C:\PS> Connect-CIServer -Server 'my.cloud.com' -Org System
C:\PS> Connect-VCAV -VCAVHost 'vcav.my.cloud.com' -VCDHost 'my.cloud.com'
Logged in to VCAV successfully
```

## Connect-VCAVExtend

This function extends an existin vCloud Availability API session to an additional vCAV site. It can be used multiple times if required to extend a single session across any number of vCAV sites. An existing VCAV session must exist and be logged in (Connect-VCAV) before the session can be extended to other sites.

Parameters:

Parameter | Type | Default | Required | Description
--------- | ---- | ------- | -------- | -----------
VCAVSiteName | string | - | True | The vCloud Availability Site Name to be extended to (e.g. 'Site2'). To see a list of available site names you can use the 'sites' query against a connected vCAV session.
VCDHost      | string | - | True | The vCloud Director API endpoint for the new site to be extended to.

Output:

A console message indicating whether the session was successfully extended or not. The connection is persisted using PowerShell session variables for the current PowerShell session.

Example (the Connect-CIServer commands will prompt for credentials):

```PowerShell
C:\PS> Connect-CIServer -Server 'site1.my.cloud.com' -Org System
C:\PS> Connect-VCAV -VCAVHost 'vcavsite1.my.cloud.com' -VCDHost 'site1.my.cloud.com'
Logged in to VCAV successfully
C:\PS> Connect-CIServer -Server 'site2.my.cloud.com' -Org System
C:\OS> Connect-VCAVExtend -VCAVSiteName 'Site2' -VCDHost 'site2.my.cloud.com'
Extended session to Site2 successfully.
```

## Disconnect-VCAV

Disconnects from any connected vCloud Availability sessions and resets the session variables.

Parameters:

None

Output:

A console message indicating whether the session was successfully disconnected or not.

Example:

```PowerShell
Disconnect-VCAV
Logged out successfully.
```

Note that Disconnect-VCAV will not disconnect or change vCloud Director API sessions, (Connect-CIServer) and you should still gracefully disconnect from the vCD API using Disconnect-CIServer after Disconnect-VCAV.

## Get-VCAVToken

This cmdlet returns the X-VCAV-Auth token established by Connect-VCAV so it can be used outside of these cmdlets if necessary in the current session. If no session exists this cmdlet will generate an error.

Parameters:

None

Output:

The current X-VCAV-Auth token (if any) as a string.

Example (assuming already successfully connected to vCAV using Connect-VCAV):

```PowerShell
C:\PS> Get-VCAVToken
LSjAy0nIjSnX25OhHSCw9Jm9f3c=
```

## Invoke-VCAVQuery

This cmdlet allows interaction with the vCloud Availability using an established session (Connect-VCAV / Connect-VCAVExtend) and supports almost any valid API interaction with the VCAV API (see Examples below).

Parameters:

Parameter | Type | Default | Required | Description
--------- | ---- | ------- | -------- | -----------
Uri | string | - | False | An absolute (full) URI to be used for the API request. Generally it is easier/safer to use the QueryPath and Filter parameters instead of this. If this parameter is specified it will override any QueryPath or Filter parameter values.
QueryPath | string | - | False | A relative API path string used to build an API request (e.g. '`sites`', '`sessions`', '`diagnostics/health`'). One of `Uri` or `QueryPath` must be specified. Available query paths are documented in the vCloud Availability 3.0 API reference at https://code.vmware.com/apis/441.
Method | string | Get | False | The HTTP verb to be used for this query, defaults to 'Get'.
Headers | hashtable | Auth and Accept | False | A hashtable of HTTP Headers to be sent with the request. Note that the X-VCAV-Auth token is populated automatically and does not need to be specified. Also the 'Accept' token defaults to 'application/vnd.vmware.h4-v3+json;charset=UTF-8' if not specified using this option which is appropriate for most (all?) vCAV API queries.
Filter | hashtable | - | False | A hashtable of query parameters typically used to filter query results (see Examples below). Acceptable filter parameters are documented in the vCloud Availability 3.0 API reference at https://code.vmware.com/apis/441.
ContentType | string | - | False | When submitting data to the API in the `-Body` parameter, this can be used to set the data type of that content (e.g. 'application/json').
Body | string | - | False | Data to be supplied to the API for a `Put`, `Patch` or other request that requires data to be sent to the API. Should be used in combination with `ContentType` to specify the data type.

Output:

A `PSCustomObject` with the returned API data or an error if the request was not successfully submitted.

Examples:

```PowerShell
C:\PS> (Invoke-VCAVQuery -QueryPath 'sites').site
site          : C00-Christchurch
site          : A03-Auckland
```

```PowerShell
C:\PS> Invoke-VCAVQuery -QueryPath 'sessions' | Format-List
user               : administrator@System
roles              : {EVERYONE, ADMINISTRATORS, VRADMINISTRATORS}
authenticatedSites : {@{site=A03-Auckland; org=System}, @{site=C00-Christchurch; org=System}}
```

```PowerShell
C:\PS> (Invoke-VCAVQuery -QueryPath 'vapp-replications' -Filter @{sourceOrg='Tyrell';vappName='webapp05'}).items.vmReplications

id                  : C4-58b613b3-4d48-44a5-a427-c8b9d8baaf3a
vmId                : 146a8c84-04ea-4160-9c8e-764c751a1eaf
vmName              : webapp05
isPaused            : False
settings            : @{description=Protected via VCAV UI; rpo=240; dataConnectionType=ENCRYPTED_COMPRESSED;
                      quiesced=True; retentionPolicy=; initialSyncTime=0}
startupInfo         : @{order=0; startAction=powerOn; startDelay=0; stopAction=powerOff; stopDelay=0}
metadata            :
sourceState         : @{state=idle; progress=; stateAge=12530946}
destinationState    : @{currentRpoViolation=0; latestInstance=; state=opened; recoveryInfo=; lastError=;
                      stateAge=12527469; spaceRequirement=5265948672; isMovingReplica=False}
dataConnectionState : OK
overallHealth       : GREEN
lastUpdated         : 1557097715639
isReversed          : False
storageProfile      : ac4c6306-2e5f-4b9f-a219-72ae3a176fbd
vimLocation         : @{vimServer=1fb0f273-5ab1-47e0-aca4-ee3eb46b0051;
                      vimServerInstanceUuid=6aac91c4-0e3a-4912-8a50-9cde471a2b6a;
                      datastore=e3e5ac05-1735-4ef4-b3fa-6bc8a349032b; datastoreMoref=datastore-12}
computerName        : webapp05
vmDescription       : Basic webapp
isMigration         : False
```

## Invoke-VCAVPagedQuery

This cmdlet functions similarly to `Invoke-VCAVQuery` but only supports the `Get` HTTP verb and deals with queries that can result in a large number of objects by requesting these in 100-object chunks and merging all responses prior to returning results.

Parameter | Type | Default | Required | Description
--------- | ---- | ------- | -------- | -----------
QueryPath | string | - | True | A relative API path string used to build an API request (e.g. `tasks` or `vapp-replications`). Available query paths are documented in the vCloud Availability 3.0 API reference at https://code.vmware.com/apis/441.
Headers | hashtable | Auth and Accept | False | A hashtable of HTTP Headers to be sent with the request. Note that the X-VCAV-Auth token is populated automatically and does not need to be specified. Also the 'Accept' token defaults to 'application/vnd.vmware.h4-v3+json;charset=UTF-8' if not specified using this option which is appropriate for most (all?) vCAV API queries.
Filter | hashtable | - | False | A hashtable of query parameters typically used to filter query results (see Examples below). Acceptable filter parameters are documented in the vCloud Availability 3.0 API reference at https://code.vmware.com/apis/441.

Output:

A `PSCustomObject` with the returned API data or an error if the request was not successfully submitted.

Example:

```PowerShell
C:\PS> Invoke-VCAVPagedQuery -QueryPath 'vapp-replications' -Filter @{sourceOrg='Tyrell';vappName='webapp05'}

id             : C4VAPP-ddc8d52a-9636-446c-a9ae-018276555d54
owner          : Tyrell@C00-Christchurch
source         : @{site=A03-Auckland; org=Tyrell; vdcId=a141dcbe-9182-496c-a8d8-f8ee49f11bfa; vdcName=A03 Tyrell
                 Allocated; vappId=85f57eb9-7311-4452-8d0e-88f2d2ba1c7e}
destination    : @{site=C00-Christchurch; org=Tyrell; vdcId=8fe75fda-a7df-4964-9c03-d1cbb3d1b711; vdcName=C00 Tyrell
                 Allocated; recoveredVappId=}
descriptor     : @{name=webapp05; description=; metadata=}
vmReplications : {@{id=C4-58b613b3-4d48-44a5-a427-c8b9d8baaf3a; vmId=146a8c84-04ea-4160-9c8e-764c751a1eaf;
                 vmName=webapp05; isPaused=False; settings=; startupInfo=; metadata=; sourceState=; destinationState=;
                 dataConnectionState=OK; overallHealth=GREEN; lastUpdated=1557097715639; isReversed=False;
                 storageProfile=ac4c6306-2e5f-4b9f-a219-72ae3a176fbd; vimLocation=; computerName=webapp05;
                 vmDescription=Basic webapp; isMigration=False}}
lastUpdated    : 1557097715620
isMigration    : False
overallHealth  : GREEN
```

## summary-report.ps1

This is an example PowerShell script which uses the PowerVCAV module to generate a report showing a summary of the vApps and VMs currently being replicated by VCAV.

Example:

```PowerShell
C:\PS> .\summary-report.ps1

Org          : Tyrell
C2CProt_vApp : 2
C2CProt_VM   : 2
C2CMig_vApp  : 0
C2CMig_VM    : 0
V2CProt_vApp : 2
V2CProt_VM   : 2
V2CMig_vApp  : 0
V2CMig_VM    : 0
C2VProt_vApp : 2
C2vProt_VM   : 2
C2VMig_vApp  : 0
C2VMig_VM    : 0
Total_vApp   : 6
Total_VM     : 6
```

The numbers show the number of vApps/VMs being protected (or migrated) for each category (Cloud-to-Cloud, vSphere-to-Cloud or Cloud-to-vSphere).

Thus report can easily be tailored to requirements by editing the summary-report.ps1 file.

## vm-report.ps1

This is an example PowerShell screipt which uses the PowerVCAV module to generate a report showing detailed VM replication information from the VCAV API:

Example:

```PowerShell
C:\PS> .\vm-report.ps1

Org            : Tyrell
Vdc            : C00 Tyrell Allocated
StoragePolicy  : C00 - Performance
vAppName       : webapp01
VMName         : webapp01
RPO            : 240 mins
Paused         : False
RPOviolated    : No
Quiesced       : True
LastStatus     : 9/05/2019 8:14:31 AM
LastXfer       : 264 KB
LastXferTime   : 2 sec
DataConnection : OK
Migration      : False
overallHealth  : GREEN
Instances      : 4
AverageXfer    : 5.7 MB/day
SpaceRequired  : 4.2 GB
```

**NOTE:** The 'AverageXfer' is calculated based on recent replication sizes and will be wildly inaccurate for the first 24 hours when new replications are configured (since the initial sync size will likely be massively larger than the ongoing replication traffic).

**NOTE:** If running vm-report.ps1 interactively, using `.vm-report.ps1 | Out-GridView` results in a much easier table to read:

![vm-report.ps1 Grid View](vm-report-out-gridview-01.png)