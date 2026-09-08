import assert from 'node:assert/strict';
import test from 'node:test';

import { stagingConfiguration, summarize } from './m8_5e_guest_fuc_staging.mjs';

test('requires an in-memory credential without echoing its value', () => {
  const secret = 'not-a-valid-token';
  assert.throws(
    () => stagingConfiguration({ STAGING_INVITATION_TOKEN: secret }),
    (error) => !error.message.includes(secret),
  );
});

test('requires at least five runs per profile', () => {
  assert.throws(() => stagingConfiguration({
    STAGING_INVITATION_TOKEN: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
    STAGING_FUC_RUNS: '4',
  }));
});

test('computes nearest-rank p90 for the bounded timing set', () => {
  assert.deepEqual(summarize([900, 500, 700, 600, 800]), {
    min_ms: 500,
    median_ms: 700,
    p90_ms: 900,
    max_ms: 900,
    mean_ms: 700,
  });
});
