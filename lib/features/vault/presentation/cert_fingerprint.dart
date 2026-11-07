/// İmza sertifikası özetini okunur biçimde yazar: `AB:CD:EF:...`.
///
/// [short] ise yalnızca ilk sekiz bayt gösterilir ve sonuna `…` konur. Liste
/// görünümleri için yeterince ayırt edicidir; güvenlik uyarılarında tamamı
/// gösterilir.
String formatCertFingerprint(String hex, {bool short = false}) {
  final upper = hex.toUpperCase();
  final pairs = [
    for (var i = 0; i + 1 < upper.length; i += 2) upper.substring(i, i + 2),
  ];
  if (short && pairs.length > 8) return '${pairs.take(8).join(':')}…';
  return pairs.join(':');
}
