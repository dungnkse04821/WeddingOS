[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-LocalValue([string[]]$Lines, [string]$Name) {
  $line = $Lines | Where-Object { $_ -match "^$Name=" } | Select-Object -First 1
  if (-not $line) { throw "Local Supabase status did not provide $Name." }
  return ($line -replace "^$Name=", '').Trim('"')
}

function Invoke-SafeRequest {
  param(
    [Parameter(Mandatory)][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [Parameter(Mandatory)][hashtable]$Headers,
    [object]$Body,
    [string]$ContentType = 'application/json'
  )

  $arguments = @{
    Method = $Method
    Uri = $Uri
    Headers = $Headers
    SkipHttpErrorCheck = $true
  }
  if ($null -ne $Body) {
    $arguments.Body = $Body
    $arguments.ContentType = $ContentType
  }
  $response = Invoke-WebRequest @arguments
  $json = $null
  if ($response.Content) {
    try { $json = $response.Content | ConvertFrom-Json } catch { $json = $response.Content }
  }
  return [pscustomobject]@{ Status = [int]$response.StatusCode; Json = $json }
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "M8.1B provider assertion failed: $Message" }
}

function Get-RowCount($Response) {
  if ($Response.Status -ne 200) { return -1 }
  if ($null -eq $Response.Json) { return 0 }
  return @($Response.Json).Count
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$statusLines = @(& npx supabase status -o env 2>$null)
$statusExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($statusExitCode -ne 0 -and -not ($statusLines | Where-Object { $_ -match '^API_URL=' })) {
  throw 'Local Supabase status did not return API connection values.'
}
$apiUrl = Get-LocalValue $statusLines 'API_URL'
$anonKey = Get-LocalValue $statusLines 'ANON_KEY'
$serviceKey = Get-LocalValue $statusLines 'SERVICE_ROLE_KEY'
$dbContainer = @(& docker ps --filter 'name=supabase_db_' --format '{{.Names}}') | Select-Object -First 1
if (-not $dbContainer) { throw 'Local Supabase database container is not running.' }

$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$password = "M81b-$([Guid]::NewGuid().ToString('N'))!"
$emails = @(
  "m81b-owner-$suffix@test.local",
  "m81b-collab-$suffix@test.local",
  "m81b-outsider-$suffix@test.local"
)
$users = @()
$weddingIds = @(
  '16f00000-0000-0000-0000-000000000001',
  '16f00000-0000-0000-0000-000000000002',
  '16f00000-0000-0000-0000-000000000003',
  '16f00000-0000-0000-0000-000000000004'
)

try {
  foreach ($email in $emails) {
    $created = Invoke-SafeRequest -Method POST -Uri "$apiUrl/auth/v1/admin/users" -Headers @{
      apikey = $serviceKey
      Authorization = "Bearer $serviceKey"
    } -Body (@{ email = $email; password = $password; email_confirm = $true } | ConvertTo-Json -Compress)
    Assert-True ($created.Status -in 200, 201) "fixture Auth user creation returned HTTP $($created.Status)"

    $session = Invoke-SafeRequest -Method POST -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers @{
      apikey = $anonKey
    } -Body (@{ email = $email; password = $password } | ConvertTo-Json -Compress)
    Assert-True ($session.Status -eq 200) "fixture sign-in returned HTTP $($session.Status)"
    $users += [pscustomobject]@{
      Id = [Guid]::Parse([string]$created.Json.id).ToString()
      Token = [string]$session.Json.access_token
    }
  }

  $ownerId = $users[0].Id
  $collabId = $users[1].Id
  $outsiderId = $users[2].Id
  $fixtureSql = @"
INSERT INTO public.weddings(id,name,cultural_context,exact_date,status) VALUES
 ('$($weddingIds[0])','M81B HTTP Active','TUY_CHON','2027-06-01','ACTIVE'),
 ('$($weddingIds[1])','M81B HTTP Archived','TUY_CHON','2027-06-02','ACTIVE'),
 ('$($weddingIds[2])','M81B HTTP Deleting','TUY_CHON','2027-06-03','ACTIVE'),
 ('$($weddingIds[3])','M81B HTTP Unrelated','TUY_CHON','2027-06-04','ACTIVE');
INSERT INTO public.wedding_members(wedding_id,user_id,display_name,profile_email,role,status) VALUES
 ('$($weddingIds[0])','$ownerId','Owner','$($emails[0])','OWNER','ACTIVE'),
 ('$($weddingIds[0])','$collabId','Collaborator','$($emails[1])','COLLABORATOR','ACTIVE'),
 ('$($weddingIds[1])','$ownerId','Owner','$($emails[0])','OWNER','ACTIVE'),
 ('$($weddingIds[1])','$collabId','Collaborator','$($emails[1])','COLLABORATOR','ACTIVE'),
 ('$($weddingIds[2])','$ownerId','Owner','$($emails[0])','OWNER','ACTIVE'),
 ('$($weddingIds[2])','$collabId','Collaborator','$($emails[1])','COLLABORATOR','ACTIVE'),
 ('$($weddingIds[3])','$outsiderId','Outsider','$($emails[2])','OWNER','ACTIVE');
INSERT INTO public.wedding_events(id,wedding_id,name,exact_date,lifecycle_status,is_main_event) VALUES
 ('16f10000-0000-0000-0000-000000000001','$($weddingIds[0])','HTTP Active Event','2027-06-01','ACTIVE',true),
 ('16f10000-0000-0000-0000-000000000002','$($weddingIds[1])','HTTP Archived Event','2027-06-02','ACTIVE',true),
 ('16f10000-0000-0000-0000-000000000003','$($weddingIds[2])','HTTP Deleting Event','2027-06-03','ACTIVE',true);
INSERT INTO public.tasks(id,wedding_id,name,status,deadline_intent,task_source,side) VALUES
 ('16f20000-0000-0000-0000-000000000001','$($weddingIds[0])','HTTP Active Task','TODO','NO_DEADLINE','USER','COMMON'),
 ('16f20000-0000-0000-0000-000000000002','$($weddingIds[1])','HTTP Archived Task','TODO','NO_DEADLINE','USER','COMMON'),
 ('16f20000-0000-0000-0000-000000000003','$($weddingIds[2])','HTTP Deleting Task','TODO','NO_DEADLINE','USER','COMMON');
INSERT INTO public.guests(id,wedding_id,name) VALUES
 ('16f30000-0000-0000-0000-000000000001','$($weddingIds[0])','HTTP Active Guest'),
 ('16f30000-0000-0000-0000-000000000002','$($weddingIds[1])','HTTP Archived Guest'),
 ('16f30000-0000-0000-0000-000000000003','$($weddingIds[2])','HTTP Deleting Guest');
INSERT INTO public.budget_items(id,wedding_id,name,estimated_cost,status) VALUES
 ('16f40000-0000-0000-0000-000000000001','$($weddingIds[0])','HTTP Active Budget',100.00,'ACTIVE'),
 ('16f40000-0000-0000-0000-000000000002','$($weddingIds[1])','HTTP Archived Budget',100.00,'ACTIVE'),
 ('16f40000-0000-0000-0000-000000000003','$($weddingIds[2])','HTTP Deleting Budget',100.00,'ACTIVE');
UPDATE public.weddings SET status='ARCHIVED' WHERE id='$($weddingIds[1])';
UPDATE public.weddings SET status='DELETING' WHERE id='$($weddingIds[2])';
"@
  $fixtureSql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null

  $webp = [byte[]](0x52,0x49,0x46,0x46,0x4D,0x38,0x31,0x42)
  foreach ($weddingId in $weddingIds[0..2]) {
    $upload = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/wedding_media/weddings/$weddingId/cover.webp" -Headers @{
      apikey = $serviceKey
      Authorization = "Bearer $serviceKey"
      'x-upsert' = 'true'
    } -Body $webp -ContentType 'image/webp'
    Assert-True ($upload.Status -eq 200) "service fixture upload returned HTTP $($upload.Status)"
  }

  function User-Headers([int]$Index) {
    return @{ apikey = $anonKey; Authorization = "Bearer $($users[$Index].Token)" }
  }
  function Read-Rows([int]$UserIndex, [string]$Table, [string]$Filter, [string]$Select = '*') {
    return Invoke-SafeRequest -Method GET -Uri "$apiUrl/rest/v1/$Table`?$Filter&select=$Select" -Headers (User-Headers $UserIndex)
  }

  $activeOwnerWedding = Read-Rows 0 'weddings' "id=eq.$($weddingIds[0])" 'id,name,status'
  $activeCollabEvent = Read-Rows 1 'wedding_events' "wedding_id=eq.$($weddingIds[0])" 'id'
  $activeOwnerBudget = Read-Rows 0 'budget_items' "wedding_id=eq.$($weddingIds[0])" 'id'
  $archivedOwnerWedding = Read-Rows 0 'weddings' "id=eq.$($weddingIds[1])" 'id,name,status'
  $archivedCollabEvent = Read-Rows 1 'wedding_events' "wedding_id=eq.$($weddingIds[1])" 'id'
  $deletingOwnerWedding = Read-Rows 0 'weddings' "id=eq.$($weddingIds[2])" 'id,name,status'
  $deletingOwnerMembers = Read-Rows 0 'wedding_members' "wedding_id=eq.$($weddingIds[2])" 'user_id,role,status'
  $deletingOwnerEvents = Read-Rows 0 'wedding_events' "wedding_id=eq.$($weddingIds[2])" 'id'
  $deletingOwnerTasks = Read-Rows 0 'tasks' "wedding_id=eq.$($weddingIds[2])" 'id'
  $deletingOwnerGuests = Read-Rows 0 'guests' "wedding_id=eq.$($weddingIds[2])" 'id'
  $deletingOwnerBudget = Read-Rows 0 'budget_items' "wedding_id=eq.$($weddingIds[2])" 'id'
  $deletingCollabWedding = Read-Rows 1 'weddings' "id=eq.$($weddingIds[2])" 'id'
  $crossWedding = Read-Rows 2 'weddings' "id=eq.$($weddingIds[0])" 'id'
  $anonWedding = Invoke-SafeRequest -Method GET -Uri "$apiUrl/rest/v1/weddings?id=eq.$($weddingIds[0])&select=id" -Headers @{ apikey = $anonKey }

  Assert-True ((Get-RowCount $activeOwnerWedding) -eq 1) 'ACTIVE owner Wedding read'
  Assert-True ((Get-RowCount $activeCollabEvent) -eq 1) 'ACTIVE collaborator graph read'
  Assert-True ((Get-RowCount $activeOwnerBudget) -eq 1) 'ACTIVE owner Finance read'
  Assert-True ((Get-RowCount $archivedOwnerWedding) -eq 1) 'ARCHIVED owner Wedding read'
  Assert-True ((Get-RowCount $archivedCollabEvent) -eq 1) 'ARCHIVED collaborator graph read'
  Assert-True ((Get-RowCount $deletingOwnerWedding) -eq 1) 'DELETING owner recovery Wedding read'
  Assert-True ((Get-RowCount $deletingOwnerMembers) -eq 1) 'DELETING owner own membership read only'
  Assert-True ((Get-RowCount $deletingOwnerEvents) -eq 0) 'DELETING owner event denial'
  Assert-True ((Get-RowCount $deletingOwnerTasks) -eq 0) 'DELETING owner task denial'
  Assert-True ((Get-RowCount $deletingOwnerGuests) -eq 0) 'DELETING owner guest denial'
  Assert-True ((Get-RowCount $deletingOwnerBudget) -eq 0) 'DELETING owner Finance denial'
  Assert-True ((Get-RowCount $deletingCollabWedding) -eq 0) 'DELETING collaborator Wedding denial'
  Assert-True ((Get-RowCount $crossWedding) -eq 0) 'cross-Wedding denial'
  Assert-True (($anonWedding.Status -ne 200) -or ((Get-RowCount $anonWedding) -eq 0)) 'anonymous denial'

  $activeStorageHeaders = User-Headers 0
  $activeStorageHeaders['x-upsert'] = 'true'
  $activeUpload = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/wedding_media/weddings/$($weddingIds[0])/cover.webp" -Headers $activeStorageHeaders -Body $webp -ContentType 'image/webp'
  $archivedUpload = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/wedding_media/weddings/$($weddingIds[1])/cover.webp" -Headers $activeStorageHeaders -Body $webp -ContentType 'image/webp'
  $deletingUpload = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/wedding_media/weddings/$($weddingIds[2])/cover.webp" -Headers $activeStorageHeaders -Body $webp -ContentType 'image/webp'
  Assert-True ($activeUpload.Status -eq 200) 'ACTIVE owner Storage upload'
  Assert-True ($archivedUpload.Status -ne 200) 'ARCHIVED owner Storage write denial'
  Assert-True ($deletingUpload.Status -ne 200) 'DELETING owner Storage write denial'

  $activeCover = Invoke-SafeRequest -Method GET -Uri "$apiUrl/storage/v1/object/authenticated/wedding_media/weddings/$($weddingIds[0])/cover.webp" -Headers (User-Headers 0)
  $archivedCover = Invoke-SafeRequest -Method GET -Uri "$apiUrl/storage/v1/object/authenticated/wedding_media/weddings/$($weddingIds[1])/cover.webp" -Headers (User-Headers 0)
  $deletingCover = Invoke-SafeRequest -Method GET -Uri "$apiUrl/storage/v1/object/authenticated/wedding_media/weddings/$($weddingIds[2])/cover.webp" -Headers (User-Headers 0)
  Assert-True ($activeCover.Status -eq 200) 'ACTIVE owner Storage read'
  Assert-True ($archivedCover.Status -eq 200) 'ARCHIVED owner Storage read'
  Assert-True ($deletingCover.Status -ne 200) 'DELETING owner Storage read denial'
  $organizerDelete = Invoke-SafeRequest -Method DELETE -Uri "$apiUrl/storage/v1/object/wedding_media" -Headers (User-Headers 0) -Body (@{ prefixes = @("weddings/$($weddingIds[0])/cover.webp") } | ConvertTo-Json -Compress)
  $afterOrganizerDelete = Invoke-SafeRequest -Method GET -Uri "$apiUrl/storage/v1/object/authenticated/wedding_media/weddings/$($weddingIds[0])/cover.webp" -Headers (User-Headers 0)
  Assert-True ($afterOrganizerDelete.Status -eq 200) 'organizer Storage DELETE has no effective authority even if provider returns success'

  [pscustomobject]@{
    Status = 'PASS'
    ActiveOwnerWedding = $activeOwnerWedding.Status
    ActiveCollaboratorGraph = $activeCollabEvent.Status
    ArchivedOwnerWedding = $archivedOwnerWedding.Status
    ArchivedCollaboratorGraph = $archivedCollabEvent.Status
    DeletingOwnerRecoveryRows = Get-RowCount $deletingOwnerWedding
    DeletingOwnerGraphRows = Get-RowCount $deletingOwnerEvents
    DeletingCollaboratorRows = Get-RowCount $deletingCollabWedding
    CrossWeddingRows = Get-RowCount $crossWedding
    AnonStatus = $anonWedding.Status
    ActiveStorageStatus = $activeCover.Status
    ArchivedStorageStatus = $archivedCover.Status
    DeletingStorageStatus = $deletingCover.Status
    ActiveStorageUpload = $activeUpload.Status
    ArchivedStorageUpload = $archivedUpload.Status
    DeletingStorageUpload = $deletingUpload.Status
    OrganizerDeleteStatus = $organizerDelete.Status
    OrganizerObjectAfterDelete = $afterOrganizerDelete.Status
  } | Format-List
}
finally {
  if ($serviceKey -and $apiUrl) {
    $paths = $weddingIds[0..2] | ForEach-Object { "weddings/$_/cover.webp" }
    Invoke-SafeRequest -Method DELETE -Uri "$apiUrl/storage/v1/object/wedding_media" -Headers @{
      apikey = $serviceKey
      Authorization = "Bearer $serviceKey"
    } -Body (@{ prefixes = $paths } | ConvertTo-Json -Compress) | Out-Null
  }
  if ($dbContainer) {
    $cleanupSql = "DELETE FROM public.weddings WHERE id = ANY(ARRAY['$($weddingIds[0])'::uuid,'$($weddingIds[1])'::uuid,'$($weddingIds[2])'::uuid,'$($weddingIds[3])'::uuid]);"
    if ($users.Count -gt 0) {
      $userIds = ($users | ForEach-Object { "'$($_.Id)'::uuid" }) -join ','
      $cleanupSql += " DELETE FROM auth.users WHERE id = ANY(ARRAY[$userIds]);"
    }
    $cleanupSql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
  }
}
