[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$dbContainer = 'supabase_db_WeddingOS'
$weddingId = '84000000-0000-4000-8000-000000000001'
$budgetItemId = '84000000-0000-4000-8000-000000000002'
$partyId = '84000000-0000-4000-8000-000000000004'
$invitationId = '84000000-0000-4000-8000-000000000005'

function Invoke-DbSql([string]$Sql) {
  $Sql | & docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q
  if ($LASTEXITCODE -ne 0) { throw 'Database benchmark setup or cleanup failed.' }
}

function Remove-BenchmarkFixture {
  Invoke-DbSql @"
DELETE FROM public.refunds WHERE budget_item_id IN (SELECT id FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid);
DELETE FROM public.payments WHERE budget_item_id IN (SELECT id FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid);
DELETE FROM public.installments WHERE budget_item_id IN (SELECT id FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid);
DELETE FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid;
DELETE FROM public.weddings WHERE id = '$weddingId'::uuid;
"@
}

function Get-PlanNodes($Plan) {
  $nodes = @($Plan.'Node Type')
  $children = $Plan.PSObject.Properties['Plans']
  if ($null -ne $children) {
    foreach ($child in @($children.Value)) { $nodes += Get-PlanNodes $child }
  }
  return $nodes
}

function Get-QueryBenchmark([string]$Name, [string]$Query) {
  $durations = @()
  $nodes = @()
  for ($iteration = 0; $iteration -lt 5; $iteration++) {
    $json = @(& docker exec $dbContainer psql -U postgres -d postgres -At -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) $Query")
    if ($LASTEXITCODE -ne 0) { throw "EXPLAIN failed for $Name." }
    $plan = (($json -join "`n") | ConvertFrom-Json)[0]
    $durations += [double]$plan.'Execution Time'
    $nodes += Get-PlanNodes $plan.Plan
  }
  $sorted = @($durations | Sort-Object)
  [pscustomobject]@{
    Query = $Name
    Rows = switch ($Name) {
      'tasks' { 500 }
      'guests' { 300 }
      'payments' { 100 }
      'refunds' { 100 }
      default { $null }
    }
    MedianMs = [math]::Round($sorted[[math]::Floor($sorted.Count / 2)], 3)
    MinMs = [math]::Round($sorted[0], 3)
    MaxMs = [math]::Round($sorted[-1], 3)
    PlanNodes = ($nodes | Sort-Object -Unique) -join ', '
  }
}

$setupSql = @"
DELETE FROM public.refunds WHERE budget_item_id IN (SELECT id FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid);
DELETE FROM public.payments WHERE budget_item_id IN (SELECT id FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid);
DELETE FROM public.installments WHERE budget_item_id IN (SELECT id FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid);
DELETE FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid;
DELETE FROM public.weddings WHERE id = '$weddingId'::uuid;
INSERT INTO public.weddings (id, name, cultural_context, expected_year, expected_month)
VALUES ('$weddingId'::uuid, 'M8.4 benchmark wedding', 'TUY_CHON', 2027, 1);
INSERT INTO public.tasks (wedding_id, name, deadline_intent, task_source, side, created_at)
SELECT '$weddingId'::uuid, 'Task ' || value, 'NO_DEADLINE', 'USER', 'COMMON', now() + value * interval '1 second'
FROM generate_series(1, 500) AS value;
INSERT INTO public.guests (wedding_id, name, side, guest_source)
SELECT '$weddingId'::uuid, 'Guest ' || lpad(value::text, 3, '0'), 'COMMON', 'OTHER'
FROM generate_series(1, 300) AS value;
INSERT INTO public.invitation_parties (id, wedding_id, display_name, invited_count)
VALUES ('$partyId'::uuid, '$weddingId'::uuid, 'Benchmark party', 2);
INSERT INTO public.invitations (id, wedding_id, invitation_party_id)
VALUES ('$invitationId'::uuid, '$weddingId'::uuid, '$partyId'::uuid);
INSERT INTO public.invitation_credentials (invitation_id, token_hash)
VALUES ('$invitationId'::uuid, decode(repeat('ab', 32), 'hex'));
INSERT INTO public.budget_items (id, wedding_id, name, estimated_cost, confirmed_cost, side, status)
VALUES ('$budgetItemId'::uuid, '$weddingId'::uuid, 'M8.4 budget', 1000000.00, 1000000.00, 'COMMON', 'ACTIVE');
INSERT INTO public.installments (budget_item_id, amount, due_date)
SELECT '$budgetItemId'::uuid, 10000.00, current_date + value
FROM generate_series(1, 100) AS value;
INSERT INTO public.payments (budget_item_id, amount, payment_date, payer_display_name)
SELECT '$budgetItemId'::uuid, 10000.00, current_date + value, 'Benchmark payer'
FROM generate_series(1, 100) AS value;
INSERT INTO public.refunds (budget_item_id, amount, refund_date, receiver)
SELECT '$budgetItemId'::uuid, 100.00, current_date + value, 'Benchmark receiver'
FROM generate_series(1, 100) AS value;
ANALYZE public.tasks;
ANALYZE public.guests;
ANALYZE public.budget_items;
ANALYZE public.installments;
ANALYZE public.payments;
ANALYZE public.refunds;
"@

try {
  Invoke-DbSql $setupSql
  $queries = @(
    @{ Name = 'tasks'; Sql = "SELECT * FROM public.tasks WHERE wedding_id = '$weddingId'::uuid ORDER BY created_at ASC" },
    @{ Name = 'guests'; Sql = "SELECT * FROM public.guests WHERE wedding_id = '$weddingId'::uuid ORDER BY name ASC" },
    @{ Name = 'budget_items'; Sql = "SELECT * FROM public.budget_items WHERE wedding_id = '$weddingId'::uuid ORDER BY created_at DESC" },
    @{ Name = 'installments'; Sql = "SELECT * FROM public.installments WHERE budget_item_id = '$budgetItemId'::uuid ORDER BY due_date ASC" },
    @{ Name = 'payments'; Sql = "SELECT * FROM public.payments WHERE budget_item_id = '$budgetItemId'::uuid ORDER BY payment_date DESC" },
    @{ Name = 'refunds'; Sql = "SELECT * FROM public.refunds WHERE budget_item_id = '$budgetItemId'::uuid ORDER BY refund_date DESC" },
    @{ Name = 'finance_summary'; Sql = "SELECT * FROM public.finance_summaries WHERE wedding_id = '$weddingId'::uuid" },
    @{ Name = 'membership_lookup'; Sql = "SELECT * FROM public.wedding_members WHERE wedding_id = '$weddingId'::uuid AND user_id = '84000000-0000-4000-8000-000000000003'::uuid" },
    @{ Name = 'credential_hash_lookup'; Sql = "SELECT * FROM public.invitation_credentials WHERE token_hash = decode(repeat('ab', 32), 'hex') AND is_active = true" }
  )
  $results = foreach ($query in $queries) { Get-QueryBenchmark $query.Name $query.Sql }
  [pscustomobject]@{ Status = 'PASS'; Fixture = '500 tasks, 300 guests, 100 payments, 100 refunds, 100 installments'; Results = $results } | ConvertTo-Json -Depth 5
}
finally {
  Remove-BenchmarkFixture
}
