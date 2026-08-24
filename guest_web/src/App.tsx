import { useEffect, useState, type Dispatch, type FormEvent, type SetStateAction } from 'react';

import { resolveInvitation, submitRsvp } from './api';
import { bootstrapInvitationToken, clearSessionToken } from './token';
import type { PublicInvitationDto, PublicInvitationEventDto, PublicRsvpDto, PublicVietQrDto, ResolveState } from './types';
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
  const [rsvp, setRsvp] = useState(invitation.rsvp);
  const [vietqr, setVietqr] = useState(invitation.vietqr);
  const [formOpen, setFormOpen] = useState(false);

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
            ? `Trạng thái phản hồi: ${rsvp.summary}. Bạn có thể cập nhật từng sự kiện.`
            : 'Thiệp hiện ở chế độ Save-the-Date. RSVP sẽ mở khi ngày chính xác được cập nhật.'}
        </p>
        {readyCount > 0 && invitation.can_submit_rsvp && !formOpen && (
          <button type="button" onClick={() => setFormOpen(true)}>Xác nhận tham dự</button>
        )}
        {readyCount > 0 && !invitation.can_submit_rsvp && <p>Đã qua hạn chốt phản hồi. Thông tin hiện ở chế độ chỉ xem.</p>}
        {formOpen && <RsvpForm invitation={invitation} setRsvp={setRsvp} setVietqr={setVietqr} />}
        {rsvp.warnings.includes('RSVP_OVERCOUNT') && <p role="status">Thiệp được chuẩn bị cho {invitation.party.invited_count} khách. Vui lòng để lại ghi chú nếu cần thêm người.</p>}
      </section>

      {vietqr.available && (
        <section className="vietqr" aria-label="Thông tin mừng cưới">
          <p className="eyebrow">Lời chúc mừng</p>
          <h2>Mừng cưới tùy tâm</h2>
          <p>Ngân hàng: {vietqr.bank_id}</p>
          <p>Số tài khoản: {vietqr.account_no}</p>
          <p>Chủ tài khoản: {vietqr.account_name}</p>
          <p className="vietqr-note">Sự hiện diện của bạn đã là niềm vui lớn với gia đình.</p>
        </section>
      )}

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

function RsvpForm({ invitation, setRsvp, setVietqr }: {
  invitation: PublicInvitationDto;
  setRsvp: Dispatch<SetStateAction<PublicRsvpDto>>;
  setVietqr: Dispatch<SetStateAction<PublicVietQrDto>>;
}) {
  const existing = new Map(invitation.rsvp.event_responses.map((response) => [response.event_id, response]));
  const [responses, setResponses] = useState(existing);
  const [changed, setChanged] = useState(new Set<string>());
  const [message, setMessage] = useState(invitation.rsvp.guest_message ?? '');
  const [dietary, setDietary] = useState(invitation.rsvp.dietary_info ?? '');
  const [companions, setCompanions] = useState((invitation.rsvp.companion_names ?? []).join(', '));
  const [note, setNote] = useState(invitation.rsvp.note ?? '');
  const [messageTouched, setMessageTouched] = useState(false);
  const [dietaryTouched, setDietaryTouched] = useState(false);
  const [companionsTouched, setCompanionsTouched] = useState(false);
  const [noteTouched, setNoteTouched] = useState(false);
  const [status, setStatus] = useState<'idle' | 'sending' | 'error'>('idle');
  const [error, setError] = useState('');

  const readyEvents = invitation.events.filter((event) => event.rsvp_ready);
  const draftAttendingCount = [...responses.values()].reduce((total, response) => total + response.attending_count, 0);
  const updateResponse = (event: PublicInvitationEventDto, responseStatus: 'ATTENDING' | 'NOT_ATTENDING', count: number) => {
    setResponses((current) => new Map(current).set(event.id, { event_id: event.id, response_status: responseStatus, attending_count: responseStatus === 'ATTENDING' ? Math.max(1, count) : 0 }));
    setChanged((current) => new Set(current).add(event.id));
  };
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (changed.size === 0) return;
    const token = bootstrapInvitationToken(window);
    if (!token.ok) { setStatus('error'); setError('Liên kết không còn khả dụng.'); return; }
    setStatus('sending'); setError('');
    const optionalFields: Record<string, unknown> = {};
    if (messageTouched) optionalFields.guest_message = message || null;
    if (dietaryTouched) optionalFields.dietary_info = dietary || null;
    if (companionsTouched) optionalFields.companion_names = companions.split(',').map((name) => name.trim()).filter(Boolean);
    if (noteTouched) optionalFields.note = note || null;
    const result = await submitRsvp(token.rawToken, {
      responses: [...changed].map((eventId) => responses.get(eventId)).filter((value): value is NonNullable<typeof value> => Boolean(value)),
      optional_fields: optionalFields,
    });
    if (result.ok) { setRsvp(result.rsvp); setVietqr(result.vietqr); return; }
    setStatus('error');
    setError(result.error_code === 'RSVP_CLOSED' ? 'Đã qua hạn chốt phản hồi.'
      : result.error_code === 'RATE_LIMITED' ? 'Vui lòng đợi một lát rồi thử lại.'
      : result.error_code === 'EVENT_NOT_AVAILABLE' ? 'Một sự kiện đã thay đổi. Hãy tải lại thiệp.'
      : result.error_code === 'INVALID_RESPONSE' ? 'Vui lòng kiểm tra lại thông tin phản hồi.'
      : 'Tạm thời chưa gửi được. Nội dung bạn đã điền vẫn được giữ lại để thử lại.');
  };

  return <form className="rsvp-form" onSubmit={submit}>
    {readyEvents.map((event) => {
      const response = responses.get(event.id);
      const attending = response?.response_status === 'ATTENDING';
      return <fieldset key={event.id} className="rsvp-event">
        <legend>{event.name}</legend>
        <label><input type="radio" name={event.id} checked={attending} onChange={() => updateResponse(event, 'ATTENDING', response?.attending_count ?? 1)} /> Tham dự</label>
        <label><input type="radio" name={event.id} checked={response?.response_status === 'NOT_ATTENDING'} onChange={() => updateResponse(event, 'NOT_ATTENDING', 0)} /> Không tham dự</label>
        {attending && <label>Số người <input aria-label={`Số người ${event.name}`} type="number" min="1" value={response.attending_count} onChange={(e) => updateResponse(event, 'ATTENDING', Number(e.target.value))} /></label>}
      </fieldset>;
    })}
    <label>Lời chúc <textarea value={message} maxLength={1000} onChange={(e) => { setMessage(e.target.value); setMessageTouched(true); }} /></label>
    <label>Lưu ý ăn kiêng <textarea value={dietary} maxLength={500} onChange={(e) => { setDietary(e.target.value); setDietaryTouched(true); }} /></label>
    <label>Người đi cùng (cách nhau bằng dấu phẩy) <textarea value={companions} maxLength={2000} onChange={(e) => { setCompanions(e.target.value); setCompanionsTouched(true); }} /></label>
    <label>Ghi chú <textarea value={note} maxLength={1000} onChange={(e) => { setNote(e.target.value); setNoteTouched(true); }} /></label>
    {draftAttendingCount > invitation.party.invited_count && <p role="status">Thiệp được chuẩn bị cho {invitation.party.invited_count} khách. Bạn vẫn có thể gửi phản hồi và để lại ghi chú.</p>}
    {error && <p role="alert">{error}</p>}
    <button type="submit" disabled={changed.size === 0 || status === 'sending'}>{status === 'sending' ? 'Đang gửi...' : 'Gửi phản hồi'}</button>
  </form>;
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
