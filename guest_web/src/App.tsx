import { useEffect, useState } from 'react';

import { resolveInvitation } from './api';
import { bootstrapInvitationToken, clearSessionToken } from './token';
import type { PublicInvitationDto, PublicInvitationEventDto, ResolveState } from './types';
import './styles.css';

export default function App() {
  const [state, setState] = useState<ResolveState>({ kind: 'loading' });

  useEffect(() => {
    let cancelled = false;
    const token = bootstrapInvitationToken(window);
    if (!token.ok) {
      setState({ kind: 'invalid' });
      return;
    }

    resolveInvitation(token.rawToken)
      .then((result) => {
        if (cancelled) return;
        if (result.ok) {
          setState({ kind: 'valid', invitation: result.invitation });
          return;
        }
        if (result.error_code === 'RATE_LIMITED') {
          setState({ kind: 'rate-limited' });
          return;
        }
        if (result.error_code === 'TEMPORARY_ERROR') {
          setState({ kind: 'temporary-error' });
          return;
        }
        clearSessionToken(window);
        setState({ kind: 'invalid' });
      })
      .catch(() => {
        if (!cancelled) setState({ kind: 'temporary-error' });
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <main className="shell">
      {state.kind === 'loading' && <StatusPanel title="Đang mở thiệp..." body="WeddingOS đang xác thực liên kết mời của bạn." />}
      {state.kind === 'invalid' && <StatusPanel title="Thiệp không khả dụng" body="Liên kết có thể đã hết hiệu lực hoặc không còn được mở." />}
      {state.kind === 'rate-limited' && <StatusPanel title="Vui lòng thử lại sau" body="Có quá nhiều yêu cầu trong thời gian ngắn. Hãy đợi một chút rồi tải lại trang." />}
      {state.kind === 'temporary-error' && <StatusPanel title="Tạm thời chưa tải được" body="Hệ thống đang bận. Vui lòng thử lại sau ít phút." />}
      {state.kind === 'valid' && <InvitationPage invitation={state.invitation} />}
    </main>
  );
}

function StatusPanel({ title, body }: { title: string; body: string }) {
  return (
    <section className="status-card" role="status">
      <p className="eyebrow">WeddingOS</p>
      <h1>{title}</h1>
      <p>{body}</p>
    </section>
  );
}

function InvitationPage({ invitation }: { invitation: PublicInvitationDto }) {
  const readyCount = invitation.events.filter((event) => event.rsvp_ready).length;

  return (
    <article className="invitation-card">
      <p className="eyebrow">Trân trọng kính mời</p>
      <h1>{invitation.party.display_name}</h1>
      <p className="wedding-name">{invitation.wedding.name}</p>
      <p className="invited-count">Số khách mời: {invitation.party.invited_count}</p>

      <section className="event-list" aria-label="Sự kiện được mời">
        {invitation.events.map((event) => (
          <EventCard key={`${event.name}-${event.date_precision}`} event={event} />
        ))}
      </section>

      <section className="rsvp-note">
        <h2>RSVP</h2>
        <p>
          {readyCount > 0
            ? 'Sự kiện có ngày chính xác đã sẵn sàng cho bước RSVP trong giai đoạn tiếp theo.'
            : 'Thiệp hiện ở chế độ Save-the-Date. RSVP sẽ mở khi ngày chính xác được cập nhật.'}
        </p>
        <button type="button" disabled>RSVP sẽ được mở sau</button>
      </section>

      {(invitation.wedding.public_contact_phone || invitation.wedding.public_contact_email) && (
        <section className="contact">
          <h2>Liên hệ</h2>
          {invitation.wedding.public_contact_phone && <p>{invitation.wedding.public_contact_phone}</p>}
          {invitation.wedding.public_contact_email && <p>{invitation.wedding.public_contact_email}</p>}
        </section>
      )}
    </article>
  );
}

function EventCard({ event }: { event: PublicInvitationEventDto }) {
  return (
    <section className="event-card">
      <p className="event-mode">{event.rsvp_ready ? 'RSVP-ready' : 'Save-the-Date'}</p>
      <h2>{event.name}</h2>
      <p>{formatEventDate(event)}</p>
      {event.start_time && <p>Thời gian: {event.start_time}</p>}
      {event.location && <p>Địa điểm: {event.location}</p>}
      {event.map_link && <a href={event.map_link} rel="noreferrer" target="_blank">Xem bản đồ</a>}
    </section>
  );
}

function formatEventDate(event: PublicInvitationEventDto): string {
  if (event.date_precision === 'EXACT' && event.exact_date) {
    return `Ngày chính xác: ${event.exact_date}`;
  }
  return `Dự kiến: Tháng ${event.expected_month}/${event.expected_year}`;
}
