/// Split story [body] into player segments (one highlight / seek unit each).
///
/// Cuts on sentence enders and paragraph breaks, but keeps trailing closers
/// (e.g. `”』）`) on the same segment as the terminator so dialogue quotes
/// are not left alone or glued to the next sentence.
List<String> splitStorySentences(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const [];

  const terminators = '。！？；!?';
  const ellipsis = '…';
  // Closing quotes / brackets that often follow 。！？ inside dialogue.
  const closers = '”’」』）)】》〉»"\'';

  final chars = <String>[
    for (final r in trimmed.runes) String.fromCharCode(r),
  ];
  final parts = <String>[];
  final buf = StringBuffer();
  var i = 0;

  bool isCloser(String ch) => closers.contains(ch);

  bool onlyClosers(String s) {
    if (s.isEmpty) return false;
    for (final r in s.runes) {
      if (!isCloser(String.fromCharCode(r))) return false;
    }
    return true;
  }

  void emit() {
    final s = buf.toString().trim();
    buf.clear();
    if (s.isEmpty) return;
    if (parts.isNotEmpty && onlyClosers(s)) {
      parts[parts.length - 1] = '${parts.last}$s';
      return;
    }
    parts.add(s);
  }

  void absorbClosers() {
    while (i < chars.length && isCloser(chars[i])) {
      buf.write(chars[i]);
      i++;
    }
  }

  while (i < chars.length) {
    final ch = chars[i];

    if (ch == '\n' || ch == '\r') {
      emit();
      while (i < chars.length && (chars[i] == '\n' || chars[i] == '\r')) {
        i++;
      }
      continue;
    }

    buf.write(ch);
    i++;

    if (terminators.contains(ch)) {
      absorbClosers();
      emit();
      continue;
    }

    if (ch == ellipsis) {
      while (i < chars.length && chars[i] == ellipsis) {
        buf.write(chars[i]);
        i++;
      }
      absorbClosers();
      emit();
      continue;
    }
  }
  emit();

  // Safety: any leftover leading closers belong to the previous segment.
  final merged = <String>[];
  for (final raw in parts) {
    var s = raw;
    if (merged.isNotEmpty) {
      var n = 0;
      final runes = s.runes.toList();
      while (n < runes.length && isCloser(String.fromCharCode(runes[n]))) {
        n++;
      }
      if (n > 0) {
        final prefix = String.fromCharCodes(runes.take(n));
        merged[merged.length - 1] = '${merged.last}$prefix';
        s = String.fromCharCodes(runes.skip(n)).trimLeft();
      }
    }
    if (s.isNotEmpty) merged.add(s);
  }

  return merged.isEmpty ? [trimmed] : merged;
}
