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
  can_submit_rsvp: boolean;
  events: PublicInvitationEventDto[];
  rsvp: PublicRsvpDto;
  vietqr: PublicVietQrDto;
};

export type PublicVietQrDto =
  | { available: false }
  | { available: true; bank_id: string; account_no: string; account_name: string };

export type PublicInvitationEventDto = {
  id: string;
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

export type PublicRsvpDto = {
  summary: 'PENDING' | 'PARTIAL' | 'RESPONDED';
  companion_names: string[] | null;
  dietary_info: string | null;
  guest_message: string | null;
  note: string | null;
  event_responses: Array<{
    event_id: string;
    response_status: 'ATTENDING' | 'NOT_ATTENDING';
    attending_count: number;
  }>;
  warnings: string[];
};

export type RsvpSubmitResponse =
  | { ok: true; can_submit_rsvp: boolean; rsvp: PublicRsvpDto; vietqr: PublicVietQrDto }
  | { ok: false; error_code: 'INVITATION_UNAVAILABLE' | 'RSVP_CLOSED' | 'INVALID_RESPONSE' | 'EVENT_NOT_AVAILABLE' | 'RATE_LIMITED' | 'TEMPORARY_UNAVAILABLE' };

export type ResolveResponse =
  | { ok: true; invitation: PublicInvitationDto }
  | { ok: false; error_code: 'INVITATION_UNAVAILABLE' | 'RATE_LIMITED' | 'TEMPORARY_ERROR' };
