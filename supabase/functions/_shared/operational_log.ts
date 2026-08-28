export type EdgeRoute =
  | 'invitation_resolve'
  | 'invitation_rsvp'
  | 'wedding_delete';

export type OperationalEvent = {
  event: 'edge_request_completed';
  route: EdgeRoute;
  outcome: 'success' | 'rejected' | 'rate_limited' | 'retry_required' | 'unexpected_error';
  status_category: '2xx' | '4xx' | '5xx';
  duration_ms: number;
  correlation_id: string;
  retry_required: boolean;
  rate_limited: boolean;
};

type LogSink = (message: string) => void;

function statusCategory(status: number): OperationalEvent['status_category'] {
  if (status >= 500) return '5xx';
  if (status >= 400) return '4xx';
  return '2xx';
}

export function logEdgeCompletion(
  route: EdgeRoute,
  correlationId: string,
  startedAt: number,
  status: number,
  sink: LogSink = console.log,
  unexpected = false,
): void {
  const rateLimited = status === 429;
  const retryRequired = status >= 500;
  const outcome: OperationalEvent['outcome'] = unexpected
    ? 'unexpected_error'
    : rateLimited
    ? 'rate_limited'
    : retryRequired
    ? 'retry_required'
    : status >= 400
    ? 'rejected'
    : 'success';

  const event: OperationalEvent = {
    event: 'edge_request_completed',
    route,
    outcome,
    status_category: statusCategory(status),
    duration_ms: Math.min(3_600_000, Math.max(0, Math.round(performance.now() - startedAt))),
    correlation_id: correlationId,
    retry_required: retryRequired,
    rate_limited: rateLimited,
  };
  sink(JSON.stringify(event));
}
