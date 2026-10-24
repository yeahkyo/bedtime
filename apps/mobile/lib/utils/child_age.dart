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

/// e.g. `4岁 3个月` — for character cards matching design copy.
String formatAgeDetailedLabel(String? birthDate, {DateTime? on}) {
  final today = on ?? DateTime.now();
  if (birthDate == null || birthDate.trim().isEmpty) return '4岁';
  final birth = DateTime.tryParse(birthDate.trim());
  if (birth == null || birth.isAfter(today)) return '0岁';
  var years = today.year - birth.year;
  var months = today.month - birth.month;
  if (today.day < birth.day) months -= 1;
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years < 0) return '0岁';
  if (months <= 0) return '$years岁';
  return '$years岁 $months个月';
}
