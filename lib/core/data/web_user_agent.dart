/// A desktop-Chrome user agent sent to DeviantArt's private web endpoints so
/// the requests look like a normal browser (the default Dart UA is rejected by
/// some endpoints). Shared by every web-session fetcher (DRY).
const String webUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
