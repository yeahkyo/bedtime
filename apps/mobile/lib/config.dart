/// API origin. Local: default below. Staging/online: Cloudflare HTTPS hostname via
/// `--dart-define=API_BASE_URL=https://bedtime-api.lullvale.com` (iOS ATS blocks
/// cleartext to non-local hosts). See docs/deploy-staging.md.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

/// True when pointing at a non-loopback / non-LAN-style local URL (heuristic for UX copy).
bool get apiBaseUrlLooksRemote {
  final u = apiBaseUrl.toLowerCase();
  if (u.contains('127.0.0.1') || u.contains('localhost')) return false;
  return u.startsWith('https://') || u.startsWith('http://');
}
