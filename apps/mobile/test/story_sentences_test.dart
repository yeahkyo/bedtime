import 'package:bedtime_mobile/utils/story_sentences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitStorySentences', () {
    test('keeps closing quote with dialogue period', () {
      const body = '小熊说：“今晚月色真好。”风轻轻吹过。';
      expect(splitStorySentences(body), [
        '小熊说：“今晚月色真好。”',
        '风轻轻吹过。',
      ]);
    });

    test('does not leave orphan quote after newline', () {
      const body = '小熊说：“晚安。”\n月亮笑了。';
      expect(splitStorySentences(body), [
        '小熊说：“晚安。”',
        '月亮笑了。',
      ]);
    });

    test('keeps book-title and paren closers', () {
      const body = '他念完《小星星》。然后睡了。';
      expect(splitStorySentences(body), [
        '他念完《小星星》。',
        '然后睡了。',
      ]);
    });

    test('treats ellipsis run as one cut', () {
      const body = '他想了想……还是闭上了眼睛。';
      expect(splitStorySentences(body), [
        '他想了想……',
        '还是闭上了眼睛。',
      ]);
    });

    test('skips blank lines without empty segments', () {
      const body = '第一句。\n\n第二句！';
      expect(splitStorySentences(body), ['第一句。', '第二句！']);
    });

    test('empty input', () {
      expect(splitStorySentences(''), isEmpty);
      expect(splitStorySentences('   '), isEmpty);
    });
  });
}
