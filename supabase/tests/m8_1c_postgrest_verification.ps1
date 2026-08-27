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
    [object]$Body
  )

  $arguments = @{
    Method = $Method
    Uri = $Uri
    Headers = $Headers
    SkipHttpErrorCheck = $true
  }
  if ($null -ne $Body) {
    $arguments.Body = $Body
    $arguments.ContentType = 'application/json'
  }
  $response = Invoke-WebRequest @arguments
  $json = $null
  if ($response.Content) {
    try { $json = $response.Content | ConvertFrom-Json } catch { $json = $response.Content }
  }
  return [pscustomobject]@{ Status = [int]$response.StatusCode; Json = $json }
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "M8.1C provider assertion failed: $Message" }
}

$statusLines = @(& npx supabase status -o env 2>$null)
$apiUrl = Get-LocalValue $statusLines 'API_URL'
$anonKey = Get-LocalValue $statusLines 'ANON_KEY'
$serviceKey = Get-LocalValue $statusLines 'SERVICE_ROLE_KEY'
$dbContainer = @(& docker ps --filter 'name=supabase_db_' --format '{{.Names}}') | Select-Object -First 1
if (-not $dbContainer) { throw 'Local Supabase database container is not running.' }

$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$password = "M81c-$([Guid]::NewGuid().ToString('N'))!"
$emails = @(
  "m81c-owner-$suffix@test.local",
  "m81c-collab-$suffix@test.local",
  "m81c-outsider-$suffix@test.local"
)
$users = @()
$weddingA = '17f00000-0000-0000-0000-000000000001'
$weddingB = '17f00000-0000-0000-0000-000000000002'
$eventA = '17f10000-0000-0000-0000-000000000001'
$eventB = '17f10000-0000-0000-0000-000000000002'
$rawToken = 'BCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk0123456'

try {
  foreach ($email in $emails) {
    $created = Invoke-SafeRequest -Method POST -Uri "$apiUrl/auth/v1/admin/users" -Headers @{
      apikey = $serviceKey
      Authorization = "Bearer $serviceKey"
    } -Body (@{ email = $email; password = $password; email_confirm = $true } | ConvertTo-Json -Compress)
    Assert-True ($created.Status -in 200, 201) "fixture Auth user creation returned HTTP $($created.Status)"

    $session = Invoke-SafeRequest -Method POST -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers @{ apikey = $anonKey } -Body (@{
      email = $email
      password = $password
    } | ConvertTo-Json -Compress)
    Assert-True ($session.Status -eq 200) "fixture sign-in returned HTTP $($session.Status)"
    $users += [pscustomobject]@{
      Id = [Guid]::Parse([string]$created.Json.id).ToString()
      Token = [string]$session.Json.access_token
    }
  }

  $fixtureSql = @"
INSERT INTO public.weddings(id,name,cultural_context,exact_date,status) VALUES
 ('$weddingA','M81C HTTP Wedding A','TUY_CHON','2027-08-17','ACTIVE'),
 ('$weddingB','M81C HTTP Wedding B','TUY_CHON','2027-08-18','ACTIVE');
INSERT INTO public.wedding_members(wedding_id,user_id,display_name,profile_email,role,status) VALUES
 ('$weddingA','$($users[0].Id)','Owner','$($emails[0])','OWNER','ACTIVE'),
 ('$weddingA','$($users[1].Id)','Collaborator','$($emails[1])','COLLABORATOR','ACTIVE'),
 ('$weddingB','$($users[2].Id)','Other Owner','$($emails[2])','OWNER','ACTIVE');
INSERT INTO public.wedding_events(id,wedding_id,name,exact_date,map_link,lifecycle_status,is_main_event) VALUES
 ('$eventA','$weddingA','HTTP Public Event','2027-08-17','https://maps.example/initial','ACTIVE',true),
 ('$eventB','$weddingB','Other Event','2027-08-18','https://maps.example/other','ACTIVE',true);
INSERT INTO public.invitation_parties(id,wedding_id,display_name,invited_count)
 VALUES ('17f20000-0000-0000-0000-000000000001','$weddingA','HTTP Party',2);
INSERT INTO public.invitations(id,wedding_id,invitation_party_id,status)
 VALUES ('17f30000-0000-0000-0000-000000000001','$weddingA','17f20000-0000-0000-0000-000000000001','DRAFT');
INSERT INTO public.invitation_event_targetings(wedding_id,invitation_id,wedding_event_id)
 VALUES ('$weddingA','17f30000-0000-0000-0000-000000000001','$eventA');
UPDATE public.invitations SET status='READY' WHERE id='17f30000-0000-0000-0000-000000000001';
INSERT INTO public.invitation_credentials(invitation_id,token_hash)
 VALUES ('17f30000-0000-0000-0000-000000000001',extensions.digest('$rawToken','sha256'));
"@
  $fixtureSql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null

  function User-Headers([int]$Index) {
    return @{
      apikey = $anonKey
      Authorization = "Bearer $($users[$Index].Token)"
      Prefer = 'return=minimal'
    }
  }

  $ownerHttps = Invoke-SafeRequest -Method PATCH -Uri "$apiUrl/rest/v1/wedding_events?id=eq.$eventA" -Headers (User-Headers 0) -Body (@{ map_link = 'https://maps.google.com/place/m81c' } | ConvertTo-Json -Compress)
  Assert-True ($ownerHttps.Status -eq 204) "OWNER HTTPS update returned HTTP $($ownerHttps.Status)"

  $javascript = Invoke-SafeRequest -Method PATCH -Uri "$apiUrl/rest/v1/wedding_events?id=eq.$eventA" -Headers (User-Headers 0) -Body (@{ map_link = 'javascript:alert(1)' } | ConvertTo-Json -Compress)
  Assert-True ($javascript.Status -eq 400) "javascript update returned HTTP $($javascript.Status) instead of 400"

  $data = Invoke-SafeRequest -Method PATCH -Uri "$apiUrl/rest/v1/wedding_events?id=eq.$eventA" -Headers (User-Headers 0) -Body (@{ map_link = 'data:text/html,test' } | ConvertTo-Json -Compress)
  Assert-True ($data.Status -eq 400) "data update returned HTTP $($data.Status) instead of 400"

  $collaborator = Invoke-SafeRequest -Method PATCH -Uri "$apiUrl/rest/v1/wedding_events?id=eq.$eventA" -Headers (User-Headers 1) -Body (@{ map_link = 'https://maps.example/collaborator' } | ConvertTo-Json -Compress)
  Assert-True ($collaborator.Status -eq 204) "existing collaborator event policy returned HTTP $($collaborator.Status)"

  $crossWedding = Invoke-SafeRequest -Method PATCH -Uri "$apiUrl/rest/v1/wedding_events?id=eq.$eventB" -Headers (User-Headers 0) -Body (@{ map_link = 'https://maps.example/cross-wedding' } | ConvertTo-Json -Compress)
  Assert-True ($crossWedding.Status -eq 204) "cross-Wedding filtered update returned HTTP $($crossWedding.Status)"

  $anonUpdate = Invoke-SafeRequest -Method PATCH -Uri "$apiUrl/rest/v1/wedding_events?id=eq.$eventA" -Headers @{ apikey = $anonKey } -Body (@{ map_link = 'https://maps.example/anon' } | ConvertTo-Json -Compress)
  Assert-True ($anonUpdate.Status -in 401, 403) "anonymous update returned HTTP $($anonUpdate.Status)"

  $stateSql = "SELECT map_link FROM public.wedding_events WHERE id='$eventA'; SELECT map_link FROM public.wedding_events WHERE id='$eventB';"
  $state = @($stateSql | & docker exec -i $dbContainer psql -U postgres -d postgres -X -A -t -v ON_ERROR_STOP=1)
  Assert-True ($state[0].Trim() -eq 'https://maps.example/collaborator') 'invalid/anonymous writes changed Wedding A map_link'
  Assert-True ($state[1].Trim() -eq 'https://maps.example/other') 'cross-Wedding write changed Wedding B map_link'

  $resolve = Invoke-SafeRequest -Method POST -Uri "$apiUrl/rest/v1/rpc/resolve_public_invitation" -Headers @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
    'Accept-Profile' = 'edge_api'
    'Content-Profile' = 'edge_api'
  } -Body (@{
    p_raw_token = $rawToken
    p_limiter_key = "D-INV-001:m81c:$suffix"
    p_rate_limit_threshold = 30
  } | ConvertTo-Json -Compress)
  Assert-True ($resolve.Status -eq 200) "D-INV-001 bridge returned HTTP $($resolve.Status)"
  Assert-True ([bool]$resolve.Json.ok) 'D-INV-001 bridge did not resolve the fixture invitation'
  $resolvedMap = [string]@($resolve.Json.invitation.events)[0].map_link
  Assert-True ($resolvedMap -eq 'https://maps.example/collaborator') 'D-INV-001 did not return the validated map_link'

  [pscustomobject]@{
    Status = 'PASS'
    OwnerHttps = $ownerHttps.Status
    JavascriptRejected = $javascript.Status
    DataRejected = $data.Status
    CollaboratorExistingPolicy = $collaborator.Status
    CrossWeddingRowsChanged = 0
    AnonymousDenied = $anonUpdate.Status
    PublicResolveBridge = $resolve.Status
    PublicMapLink = $resolvedMap
  } | Format-List
}
finally {
  if ($dbContainer) {
    $cleanupSql = "DELETE FROM public.weddings WHERE id IN ('$weddingA'::uuid,'$weddingB'::uuid);"
    if ($users.Count -gt 0) {
      $userIds = ($users | ForEach-Object { "'$($_.Id)'::uuid" }) -join ','
      $cleanupSql += " DELETE FROM auth.users WHERE id = ANY(ARRAY[$userIds]);"
    }
    $cleanupSql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
  }
}
