import { logEdgeCompletion } from './operational_log.ts';

Deno.test('structured operational event contains only bounded allowlisted fields', () => {
  const messages: string[] = [];
  logEdgeCompletion(
    'invitation_resolve',
    'f725ce86-b5fd-4470-a423-abece6a2ca4d',
    performance.now(),
    429,
    (message) => messages.push(message),
  );

  const event = JSON.parse(messages[0]);
  const keys = Object.keys(event).sort();
  const expected = [
    'correlation_id',
    'duration_ms',
    'event',
    'outcome',
    'rate_limited',
    'retry_required',
    'route',
    'status_category',
  ].sort();
  if (JSON.stringify(keys) !== JSON.stringify(expected)) {
    throw new Error(`unexpected log shape: ${JSON.stringify(keys)}`);
  }
  if (event.outcome !== 'rate_limited' || event.rate_limited !== true) {
    throw new Error('rate-limit outcome was not classified');
  }
});

Deno.test('structured operational event cannot carry request or credential material', () => {
  const messages: string[] = [];
  logEdgeCompletion(
    'wedding_delete',
    '65f67e91-3032-41e2-8a22-f6bddcca8652',
    performance.now(),
    503,
    (message) => messages.push(message),
  );

  const serialized = messages[0];
  for (const forbidden of ['token', 'authorization', 'signed_url', 'service_role', 'body', 'guest']) {
    if (serialized.toLowerCase().includes(forbidden)) {
      throw new Error(`sensitive field leaked: ${forbidden}`);
    }
  }
  const event = JSON.parse(serialized);
  if (event.outcome !== 'retry_required' || event.retry_required !== true) {
    throw new Error('retry outcome was not classified');
  }
});

Deno.test('Class-D provenance logs only bounded provenance fields', () => {
  const messages: string[] = [];
  logEdgeCompletion(
    'invitation_resolve',
    'f725ce86-b5fd-4470-a423-abece6a2ca4d',
    performance.now(),
    200,
    (message) => messages.push(message),
    false,
    {
      provenance: 'cloudflare',
      trustedGateway: true,
      trustedCfIpPresent: true,
      gatewayProofEnvPresent: true,
      gatewayProofHeaderPresent: true,
      gatewayProofMatch: true,
    },
  );

  const serialized = messages[0];
  for (const forbidden of ['198.51.100.17', 'gateway-proof', 'token', 'authorization']) {
    if (serialized.toLowerCase().includes(forbidden)) {
      throw new Error(`sensitive provenance material leaked: ${forbidden}`);
    }
  }
  const event = JSON.parse(serialized);
  if (
    event.provenance !== 'cloudflare' ||
    event.trusted_gateway !== true ||
    event.trusted_cf_ip_present !== true ||
    event.gateway_proof_env_present !== true ||
    event.gateway_proof_header_present !== true ||
    event.gateway_proof_match !== true
  ) {
    throw new Error('Class-D provenance evidence was not logged.');
  }
});
