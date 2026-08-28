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
  $arguments = @{ Method = $Method; Uri = $Uri; Headers = $Headers; SkipHttpErrorCheck = $true }
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
  if (-not $Condition) { throw "M8.2A provider assertion failed: $Message" }
}

$statusLines = @(& cmd /d /c "npx supabase status -o env 2>NUL")
if ($LASTEXITCODE -ne 0) { throw 'Local Supabase status command failed.' }
$apiUrl = Get-LocalValue $statusLines 'API_URL'
$anonKey = Get-LocalValue $statusLines 'ANON_KEY'
$serviceKey = Get-LocalValue $statusLines 'SERVICE_ROLE_KEY'
$dbContainer = @(& docker ps --filter 'name=supabase_db_' --format '{{.Names}}') | Select-Object -First 1
if (-not $dbContainer) { throw 'Local Supabase database container is not running.' }

$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$email = "m82a-owner-$suffix@test.local"
$password = "M82a-$([Guid]::NewGuid().ToString('N'))!"
$publicWedding = '82a00000-0000-0000-0000-000000000001'
$deleteWedding = '82a00000-0000-0000-0000-000000000002'
$eventId = '82a10000-0000-4000-8000-000000000001'
$rawToken = 'CDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk01234567'
$userId = $null
$storagePaths = @("weddings/$deleteWedding/cover.webp", "weddings/$deleteWedding/nested/extra.webp") + (
  0..100 | ForEach-Object { "weddings/$deleteWedding/pagination/object-$($_.ToString('000')).webp" }
)

try {
  $created = Invoke-SafeRequest -Method POST -Uri "$apiUrl/auth/v1/admin/users" -Headers @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
  } -Body (@{ email = $email; password = $password; email_confirm = $true } | ConvertTo-Json -Compress)
  Assert-True ($created.Status -in 200, 201) "fixture Auth user creation returned HTTP $($created.Status)"
  $userId = [Guid]::Parse([string]$created.Json.id).ToString()

  $session = Invoke-SafeRequest -Method POST -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers @{ apikey = $anonKey } -Body (@{
    email = $email
    password = $password
  } | ConvertTo-Json -Compress)
  Assert-True ($session.Status -eq 200) "fixture sign-in returned HTTP $($session.Status)"
  $accessToken = [string]$session.Json.access_token

  $fixtureSql = @"
INSERT INTO public.weddings(id,name,cultural_context,exact_date,status) VALUES
 ('$publicWedding','M82A Public Wedding','TUY_CHON','2027-09-20','ACTIVE'),
 ('$deleteWedding','M82A Delete Wedding','TUY_CHON','2027-09-21','ACTIVE');
INSERT INTO public.wedding_members(wedding_id,user_id,display_name,profile_email,role,status) VALUES
 ('$publicWedding','$userId','M82A Owner','$email','OWNER','ACTIVE'),
 ('$deleteWedding','$userId','M82A Owner','$email','OWNER','ACTIVE');
INSERT INTO public.wedding_events(id,wedding_id,name,exact_date,map_link,lifecycle_status,is_main_event)
 VALUES ('$eventId','$publicWedding','M82A Event','2027-09-20','https://maps.example/m82a','ACTIVE',true);
INSERT INTO public.invitation_parties(id,wedding_id,display_name,invited_count)
 VALUES ('82a20000-0000-0000-0000-000000000001','$publicWedding','M82A Party',2);
INSERT INTO public.invitations(id,wedding_id,invitation_party_id,status)
 VALUES ('82a30000-0000-0000-0000-000000000001','$publicWedding','82a20000-0000-0000-0000-000000000001','DRAFT');
INSERT INTO public.invitation_event_targetings(wedding_id,invitation_id,wedding_event_id)
 VALUES ('$publicWedding','82a30000-0000-0000-0000-000000000001','$eventId');
UPDATE public.invitations SET status='READY' WHERE id='82a30000-0000-0000-0000-000000000001';
INSERT INTO public.invitation_credentials(invitation_id,token_hash)
 VALUES ('82a30000-0000-0000-0000-000000000001',extensions.digest('$rawToken','sha256'));
"@
  $fixtureSql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null

  $webp = [byte[]](0x52,0x49,0x46,0x46,0x4D,0x38,0x32,0x41)
  foreach ($path in $storagePaths) {
    $upload = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/wedding_media/$path" -Headers @{
      apikey = $serviceKey
      Authorization = "Bearer $serviceKey"
      'x-upsert' = 'true'
    } -Body $webp -ContentType 'image/webp'
    Assert-True ($upload.Status -eq 200) "Storage fixture upload returned HTTP $($upload.Status)"
  }

  $pageOne = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/list/wedding_media" -Headers @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
  } -Body (@{ prefix = "weddings/$deleteWedding/pagination/"; limit = 100; offset = 0 } | ConvertTo-Json -Compress)
  $pageTwo = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/list/wedding_media" -Headers @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
  } -Body (@{ prefix = "weddings/$deleteWedding/pagination/"; limit = 100; offset = 100 } | ConvertTo-Json -Compress)
  Assert-True (@($pageOne.Json).Count -eq 100) "Storage pagination first page returned $(@($pageOne.Json).Count) entries"
  Assert-True (@($pageTwo.Json).Count -ge 1) "Storage pagination second page returned no entries"

  $guestHeaders = @{ apikey = $anonKey; Origin = 'http://localhost:5173'; 'x-forwarded-for' = '198.51.100.82' }
  $resolve = Invoke-SafeRequest -Method POST -Uri "$apiUrl/functions/v1/invitation-resolve" -Headers $guestHeaders -Body (@{ raw_token = $rawToken } | ConvertTo-Json -Compress)
  Assert-True ($resolve.Status -eq 200 -and [bool]$resolve.Json.ok) "invitation resolve returned HTTP $($resolve.Status)"

  $rsvp = Invoke-SafeRequest -Method POST -Uri "$apiUrl/functions/v1/invitation-rsvp" -Headers $guestHeaders -Body (@{
    raw_token = $rawToken
    responses = @(@{ event_id = $eventId; response_status = 'ATTENDING'; attending_count = 2 })
    optional_fields = @{ guest_message = 'M8.2A provider smoke' }
  } | ConvertTo-Json -Depth 5 -Compress)
  Assert-True ($rsvp.Status -eq 200 -and [bool]$rsvp.Json.ok) "RSVP returned HTTP $($rsvp.Status)"

  $invalidResolve = Invoke-SafeRequest -Method POST -Uri "$apiUrl/functions/v1/invitation-resolve" -Headers $guestHeaders -Body (@{
    raw_token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012340'
    wedding_id = $deleteWedding
  } | ConvertTo-Json -Compress)
  Assert-True ($invalidResolve.Status -eq 404) "invalid credential returned HTTP $($invalidResolve.Status)"

  "UPDATE public.invitation_credentials SET is_active = false, revoked_at = now() WHERE invitation_id = '82a30000-0000-0000-0000-000000000001';" | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
  $revokedResolve = Invoke-SafeRequest -Method POST -Uri "$apiUrl/functions/v1/invitation-resolve" -Headers $guestHeaders -Body (@{ raw_token = $rawToken } | ConvertTo-Json -Compress)
  Assert-True ($revokedResolve.Status -eq 404) "revoked credential returned HTTP $($revokedResolve.Status)"

  $delete = Invoke-SafeRequest -Method POST -Uri "$apiUrl/functions/v1/wedding-delete" -Headers @{
    apikey = $anonKey
    Authorization = "Bearer $accessToken"
  } -Body (@{ wedding_id = $deleteWedding } | ConvertTo-Json -Compress)
  Assert-True ($delete.Status -eq 200 -and [string]$delete.Json.status -eq 'DELETED') "wedding delete returned HTTP $($delete.Status)"

  $storageList = Invoke-SafeRequest -Method POST -Uri "$apiUrl/storage/v1/object/list/wedding_media" -Headers @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
  } -Body (@{ prefix = "weddings/$deleteWedding/"; limit = 100; offset = 0 } | ConvertTo-Json -Compress)
  Assert-True ($storageList.Status -eq 200 -and @($storageList.Json).Count -eq 0) 'delete prefix was not empty after terminal success'

  $postconditionSql = "SELECT count(*) FROM public.weddings WHERE id='$deleteWedding'; SELECT count(*) FROM auth.users WHERE id='$userId';"
  $postcondition = @($postconditionSql | & docker exec -i $dbContainer psql -U postgres -d postgres -X -A -t -v ON_ERROR_STOP=1)
  Assert-True ($postcondition[0].Trim() -eq '0') 'Wedding row remained after terminal delete'
  Assert-True ($postcondition[1].Trim() -eq '1') 'auth.users was not preserved'

  [pscustomobject]@{
    Status = 'PASS'
    InvitationResolve = $resolve.Status
    RsvpSubmit = $rsvp.Status
    InvalidCredential = $invalidResolve.Status
    RevokedCredential = $revokedResolve.Status
    WeddingDelete = $delete.Status
    DeleteStorageEntries = @($storageList.Json).Count
    ProviderPaginationPageOne = @($pageOne.Json).Count
    ProviderPaginationPageTwo = @($pageTwo.Json).Count
    DeletedWeddingRows = [int]$postcondition[0]
    PreservedAuthUsers = [int]$postcondition[1]
  } | Format-List
}
finally {
  if ($serviceKey -and $apiUrl -and $storagePaths) {
    Invoke-SafeRequest -Method DELETE -Uri "$apiUrl/storage/v1/object/wedding_media" -Headers @{
      apikey = $serviceKey
      Authorization = "Bearer $serviceKey"
    } -Body (@{ prefixes = $storagePaths } | ConvertTo-Json -Compress) | Out-Null
  }
  if ($dbContainer) {
    $cleanupSql = "DELETE FROM public.event_responses WHERE wedding_event_id='$eventId'::uuid; DELETE FROM public.weddings WHERE id IN ('$publicWedding'::uuid,'$deleteWedding'::uuid);"
    if ($userId) { $cleanupSql += " DELETE FROM auth.users WHERE id='$userId'::uuid;" }
    $cleanupSql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
  }
}
