/// Display helpers for child age — UI shows years, not internal age_band.
int ageYearsFromBirthDate(String? raw, {DateTime? on}) {
  final today = on ?? DateTime.now();
  if (raw == null || raw.trim().isEmpty) return 4;
  final birth = DateTime.tryParse(raw.trim());
  if (birth == null) return 4;
  if (birth.isAfter(today)) return 0;
  var years = today.year - birth.year;
  if (today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day)) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}

/// e.g. `3岁`
String formatAgeYearsLabel(String? birthDate, {DateTime? on}) {
  return '${ageYearsFromBirthDate(birthDate, on: on)}岁';
}
