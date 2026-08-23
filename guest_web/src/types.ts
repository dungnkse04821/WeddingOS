export type ResolveState =
  | { kind: 'loading' }
  | { kind: 'valid'; invitation: PublicInvitationDto }
  | { kind: 'invalid' }
  | { kind: 'rate-limited' }
  | { kind: 'temporary-error' };

export type PublicInvitationDto = {
  wedding: {
    name: string;
    timezone: string;
    rsvp_cutoff_date: string | null;
    public_contact_phone: string | null;
    public_contact_email: string | null;
  };
  party: {
    display_name: string;
    invited_count: number;
  };
  status: 'READY' | 'MARKED_AS_SENT';
  can_submit_rsvp: false;
  events: PublicInvitationEventDto[];
};

export type PublicInvitationEventDto = {
  name: string;
  date_precision: 'EXACT' | 'EXPECTED_MONTH';
  exact_date: string | null;
  expected_year: number | null;
  expected_month: number | null;
  start_time: string | null;
  location: string | null;
  map_link: string | null;
  rsvp_ready: boolean;
};

export type ResolveResponse =
  | { ok: true; invitation: PublicInvitationDto }
  | { ok: false; error_code: 'INVITATION_UNAVAILABLE' | 'RATE_LIMITED' | 'TEMPORARY_ERROR' };
