/// Builds the shareable dashboard URL for a finished scan.
///
/// The backend returns a link in its `data` field, but the host can be
/// malformed (it may glue the host directly to the path when
/// `SCAN_MY_NET_UI_URL` lacks a trailing slash). Rather than trust it, we
/// pull out the `verification_token` and rebuild the URL against the
/// caller-supplied [frontendBaseUrl] — mirroring what the native app does:
///
///   `{frontendBaseUrl}#/view-report?verification_token={token}`
///
/// Falls back to the raw value if no token can be found.
String buildReportUrl({
  required String frontendBaseUrl,
  required String rawData,
}) {
  final token = _extractVerificationToken(rawData);
  if (token == null) return rawData;

  final normalized =
      frontendBaseUrl.endsWith('/') ? frontendBaseUrl : '$frontendBaseUrl/';
  return '$normalized#/view-report?verification_token=$token';
}

/// Extracts the `verification_token` from the backend's report link, tolerant of
/// both well‑formed and slash‑bug URLs (the token lives in the query either way).
String? _extractVerificationToken(String rawData) {
  final fromQuery = Uri.tryParse(rawData)?.queryParameters['verification_token'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  // Fallback: scan manually (e.g. when the token is in a fragment).
  const marker = 'verification_token=';
  final start = rawData.indexOf(marker);
  if (start == -1) return null;
  var token = rawData.substring(start + marker.length);
  final end = token.indexOf(RegExp(r'[&#]'));
  if (end != -1) token = token.substring(0, end);
  return token.isEmpty ? null : token;
}
