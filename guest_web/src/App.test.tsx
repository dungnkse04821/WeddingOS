import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
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
  can_submit_rsvp: true,
  vietqr: { available: false },
  rsvp: {
    summary: 'PENDING', companion_names: null, dietary_info: null, guest_message: null, note: null,
    event_responses: [], warnings: [],
  },
  events: [
    {
      id: 'e1000000-0000-4000-8000-000000000001',
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
      id: 'e1000000-0000-4000-8000-000000000002',
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
  cleanup();
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
    expect(screen.getByRole('button', { name: 'Xác nhận tham dự' })).toBeEnabled();
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

  it('submits only the changed RSVP event and shows the authoritative warning', async () => {
    const updated = {
      ...invitation.rsvp,
      summary: 'PARTIAL',
      event_responses: [{ event_id: invitation.events[0].id, response_status: 'ATTENDING', attending_count: 5 }],
      warnings: ['RSVP_OVERCOUNT'],
    };
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true, invitation }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: true, can_submit_rsvp: true, rsvp: updated, vietqr: { available: true, bank_id: 'VCB', account_no: '0123456789', account_name: 'NGUYEN VAN A' } }), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    window.history.replaceState(null, '', `/#/invite/${token}`);
    render(<App />);

    fireEvent.click(await screen.findByRole('button', { name: 'Xác nhận tham dự' }));
    fireEvent.click(screen.getByLabelText('Tham dự'));
    fireEvent.click(screen.getByRole('button', { name: 'Gửi phản hồi' }));

    await screen.findByText('Trạng thái phản hồi: PARTIAL. Bạn có thể cập nhật từng sự kiện.');
    const request = fetchMock.mock.calls[1][1] as { body: string };
    const body = JSON.parse(request.body);
    expect(body.responses).toEqual([{ event_id: invitation.events[0].id, response_status: 'ATTENDING', attending_count: 1 }]);
    expect(screen.getByText('Thiệp được chuẩn bị cho 4 khách. Vui lòng để lại ghi chú nếu cần thêm người.')).toBeInTheDocument();
    expect(screen.getByText('Số tài khoản: 0123456789')).toBeInTheDocument();
  });

  it('does not render bank facts when the authoritative DTO marks VietQR unavailable', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: true, invitation }), { status: 200 })));
    window.history.replaceState(null, '', `/#/invite/${token}`);
    render(<App />);
    await screen.findByText('Gia đình bác Tư');
    expect(screen.queryByLabelText('Thông tin mừng cưới')).not.toBeInTheDocument();
    expect(screen.queryByText(/Số tài khoản:/)).not.toBeInTheDocument();
  });
});
