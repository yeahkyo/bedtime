import 'package:flutter_test/flutter_test.dart';

import 'package:bedtime_mobile/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const BedtimeApp());
    expect(find.byType(BedtimeApp), findsOneWidget);
  });
}
