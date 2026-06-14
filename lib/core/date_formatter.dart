/// Единый формат дат в приложении: DD.MM.YYYY
class AppDateFormatter {
  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String formatDateTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '${formatDate(date)} в $hours:$minutes';
  }

  static String formatDateString(String dateString) {
    final raw = dateString.trim();
    if (raw.isEmpty) return '';

    try {
      return formatDate(DateTime.parse(raw));
    } catch (_) {}

    final parts = raw.split(RegExp(r'[.\-/]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0].trim());
      final month = int.tryParse(parts[1].trim());
      final year = int.tryParse(parts[2].trim());
      if (day != null && month != null && year != null) {
        return formatDate(DateTime(year, month, day));
      }
    }

    return raw;
  }

  static String formatDateTimeString(String dateString) {
    final raw = dateString.trim();
    if (raw.isEmpty) return '';

    try {
      return formatDateTime(DateTime.parse(raw));
    } catch (_) {}

    return formatDateString(raw);
  }
}
