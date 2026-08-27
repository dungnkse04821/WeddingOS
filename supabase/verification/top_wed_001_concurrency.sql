\set ON_ERROR_STOP on
\if :{?m8_db_connection}
\else
  \echo 'm8_db_connection psql variable is required'
  \quit
\endif

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA extensions;

DELETE FROM public.weddings WHERE name = 'M81B Real Concurrency';
DELETE FROM auth.users WHERE id = '16d00000-0000-0000-0000-000000000001';
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES (
  '16d00000-0000-0000-0000-000000000001',
  'm81b-concurrency@test.local',
  '{"full_name":"M81B Concurrent Owner"}'
);

SELECT extensions.dblink_connect(
  'm81b_caller_1',
  :'m8_db_connection'
);
SELECT extensions.dblink_connect(
  'm81b_caller_2',
  :'m8_db_connection'
);
SELECT extensions.dblink_exec('m81b_caller_1', 'SET ROLE authenticated');
SELECT extensions.dblink_exec('m81b_caller_2', 'SET ROLE authenticated');
SELECT extensions.dblink_exec(
  'm81b_caller_1',
  'SET request.jwt.claims = ''{"sub":"16d00000-0000-0000-0000-000000000001"}'''
);
SELECT extensions.dblink_exec(
  'm81b_caller_2',
  'SET request.jwt.claims = ''{"sub":"16d00000-0000-0000-0000-000000000001"}'''
);

CREATE TEMP TABLE m81b_concurrency_results (
  caller integer PRIMARY KEY,
  replayed boolean NOT NULL,
  wedding_id uuid NOT NULL
);

SELECT extensions.dblink_send_query(
  'm81b_caller_1',
  $$SELECT (r->>'replayed')::boolean, (r->'wedding'->>'id')::uuid
    FROM (SELECT api_v1.create_wedding(
      '16e00000-0000-0000-0000-000000000001',
      'M81B Real Concurrency',
      'TUY_CHON',
      '2027-05-01'
    ) AS r) q$$
);
SELECT extensions.dblink_send_query(
  'm81b_caller_2',
  $$SELECT (r->>'replayed')::boolean, (r->'wedding'->>'id')::uuid
    FROM (SELECT api_v1.create_wedding(
      '16e00000-0000-0000-0000-000000000001',
      'M81B Real Concurrency',
      'TUY_CHON',
      '2027-05-01'
    ) AS r) q$$
);

INSERT INTO m81b_concurrency_results (caller, replayed, wedding_id)
SELECT 1, replayed, wedding_id
FROM extensions.dblink_get_result('m81b_caller_1') AS result(replayed boolean, wedding_id uuid);
INSERT INTO m81b_concurrency_results (caller, replayed, wedding_id)
SELECT 2, replayed, wedding_id
FROM extensions.dblink_get_result('m81b_caller_2') AS result(replayed boolean, wedding_id uuid);

DO $$
BEGIN
  IF (SELECT count(*) FROM m81b_concurrency_results) <> 2 THEN
    RAISE EXCEPTION 'CONCURRENCY_ASSERTION_FAILED: expected two caller results';
  END IF;
  IF (SELECT count(DISTINCT wedding_id) FROM m81b_concurrency_results) <> 1 THEN
    RAISE EXCEPTION 'CONCURRENCY_ASSERTION_FAILED: callers returned different Weddings';
  END IF;
  IF (SELECT count(*) FROM public.weddings WHERE name = 'M81B Real Concurrency') <> 1 THEN
    RAISE EXCEPTION 'CONCURRENCY_ASSERTION_FAILED: expected one committed Wedding';
  END IF;
  IF (
    SELECT count(*)
    FROM private.trusted_operation_receipts
    WHERE operation_type = 'TOP-WED-001'
      AND actor_user_id = '16d00000-0000-0000-0000-000000000001'
      AND request_id = '16e00000-0000-0000-0000-000000000001'
  ) <> 1 THEN
    RAISE EXCEPTION 'CONCURRENCY_ASSERTION_FAILED: expected one authoritative receipt';
  END IF;
  IF (SELECT count(*) FROM m81b_concurrency_results WHERE replayed = false) <> 1
     OR (SELECT count(*) FROM m81b_concurrency_results WHERE replayed = true) <> 1 THEN
    RAISE EXCEPTION 'CONCURRENCY_ASSERTION_FAILED: expected one create and one converged replay';
  END IF;
END;
$$;

SELECT extensions.dblink_disconnect('m81b_caller_1');
SELECT extensions.dblink_connect(
  'm81b_caller_1',
  :'m8_db_connection'
);
SELECT extensions.dblink_exec('m81b_caller_1', 'SET ROLE authenticated');
SELECT extensions.dblink_exec(
  'm81b_caller_1',
  'SET request.jwt.claims = ''{"sub":"16d00000-0000-0000-0000-000000000001"}'''
);
SELECT extensions.dblink_send_query(
  'm81b_caller_1',
  $$SELECT api_v1.create_wedding(
    '16e00000-0000-0000-0000-000000000001',
    'M81B Different Semantics',
    'TUY_CHON',
    '2027-05-01'
  )$$
);
SELECT *
FROM extensions.dblink_get_result('m81b_caller_1', false) AS ignored(result jsonb);

DO $$
BEGIN
  IF extensions.dblink_error_message('m81b_caller_1') NOT LIKE '%REQUEST_ID_REUSED%' THEN
    RAISE EXCEPTION 'CONCURRENCY_ASSERTION_FAILED: semantic mismatch was not rejected';
  END IF;
END;
$$;

SELECT
  'PASS' AS status,
  count(*) AS concurrent_callers,
  count(DISTINCT wedding_id) AS distinct_returned_weddings,
  min(wedding_id::text) AS converged_wedding_id,
  (SELECT count(*) FROM public.weddings WHERE name = 'M81B Real Concurrency') AS committed_weddings,
  (
    SELECT count(*)
    FROM private.trusted_operation_receipts
    WHERE operation_type = 'TOP-WED-001'
      AND actor_user_id = '16d00000-0000-0000-0000-000000000001'
      AND request_id = '16e00000-0000-0000-0000-000000000001'
  ) AS receipts,
  'REQUEST_ID_REUSED' AS semantic_mismatch_result
FROM m81b_concurrency_results;

SELECT extensions.dblink_disconnect('m81b_caller_1');
SELECT extensions.dblink_disconnect('m81b_caller_2');
DELETE FROM public.weddings WHERE name = 'M81B Real Concurrency';
DELETE FROM auth.users WHERE id = '16d00000-0000-0000-0000-000000000001';
DROP EXTENSION dblink;
