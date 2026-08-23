import { render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import App from './App';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345';

const invitation = {
  wedding: {
    name: 'Active Wedding',
    timezone: 'Asia/Ho_Chi_Minh',
    rsvp_cutoff_date: null,
    public_contact_phone: '0900000000',
    public_contact_email: 'hello@example.com',
  },
  party: {
    display_name: 'Gia đình bác Tư',
    invited_count: 4,
  },
  status: 'READY',
  can_submit_rsvp: false,
  events: [
    {
      name: 'Exact Event',
      date_precision: 'EXACT',
      exact_date: '2026-12-18',
      expected_year: null,
      expected_month: null,
      start_time: '18:00',
      location: 'Main Hall',
      map_link: null,
      rsvp_ready: true,
    },
    {
      name: 'Expected Month Event',
      date_precision: 'EXPECTED_MONTH',
      exact_date: null,
      expected_year: 2026,
      expected_month: 12,
      start_time: null,
      location: null,
      map_link: null,
      rsvp_ready: false,
    },
  ],
};

afterEach(() => {
  vi.restoreAllMocks();
  window.sessionStorage.clear();
  window.localStorage.clear();
  window.history.replaceState(null, '', '/');
});

describe('Guest invitation shell', () => {
  it('renders valid resolve with Exact and Expected Month states', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: true, invitation }), { status: 200 })));
    window.history.replaceState(null, '', `/#/invite/${token}`);

    render(<App />);

    expect(await screen.findByText('Gia đình bác Tư')).toBeInTheDocument();
    expect(screen.getByText('Ngày chính xác: 2026-12-18')).toBeInTheDocument();
    expect(screen.getByText('Dự kiến: Tháng 12/2026')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'RSVP sẽ được mở sau' })).toBeDisabled();
    expect(window.location.hash).toBe('');
    expect(window.localStorage.length).toBe(0);
  });

  it('renders invalid invitation state and clears session token', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: false, error_code: 'INVITATION_UNAVAILABLE' }), { status: 404 })));
    window.history.replaceState(null, '', `/#/invite/${token}`);

    render(<App />);

    expect(await screen.findByText('Thiệp không khả dụng')).toBeInTheDocument();
    await waitFor(() => expect(window.sessionStorage.length).toBe(0));
  });

  it('renders rate limited and temporary error states', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: false, error_code: 'RATE_LIMITED' }), { status: 429 })));
    window.history.replaceState(null, '', `/#/invite/${token}`);
    const { unmount } = render(<App />);
    expect(await screen.findByText('Vui lòng thử lại sau')).toBeInTheDocument();
    unmount();

    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: false, error_code: 'TEMPORARY_ERROR' }), { status: 503 })));
    window.history.replaceState(null, '', `/#/invite/${token}`);
    render(<App />);
    expect(await screen.findByText('Tạm thời chưa tải được')).toBeInTheDocument();
  });
});
