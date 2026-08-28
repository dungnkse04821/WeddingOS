import { proxyInvitationRequest, type ProxyEnvironment } from '../../../_shared/invitation_proxy';

export const onRequest = ({ request, env }: { request: Request; env: ProxyEnvironment }) =>
  proxyInvitationRequest(request, env, 'invitation-resolve');
