/// Removes credentials, tokens, and personally identifying fragments from a
/// diagnostic line before it is offered to the user for a bug report. This is a
/// conservative, best-effort redactor: it targets the obvious secrets and lets
/// ordinary log text through so a report stays useful.
final class LogRedactor {
  const LogRedactor._();

  static final List<RegExp> _patterns = <RegExp>[
    // OAuth / session parameters and their values, whether in a query string
    // (`?token=…`) or plain `key=value` text.
    RegExp(
      r'\b((?:access_token|refresh_token|id_token|csrf_token|client_secret|signature|sig|token|code|state)=)[^\s&,;]+',
      caseSensitive: false,
    ),
    // Header lines that carry credentials or a browser session.
    RegExp(r'(Cookie:\s*).*', caseSensitive: false),
    RegExp(r'(Authorization:\s*).*', caseSensitive: false),
    // Email addresses.
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'),
  ];

  static String redact(String line) {
    var result = line;
    for (final pattern in _patterns) {
      result = result.replaceAllMapped(
        pattern,
        (match) =>
            '${match.groupCount > 0 ? match.group(1) ?? '' : ''}[redacted]',
      );
    }
    return result;
  }

  static String redactAll(String text) =>
      text.split('\n').map(redact).join('\n');
}
