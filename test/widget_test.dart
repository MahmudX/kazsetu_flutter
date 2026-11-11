import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazsetu_mobile/api.dart';
import 'package:kazsetu_mobile/i18n.dart';
import 'package:kazsetu_mobile/screens/find_work.dart';
import 'package:kazsetu_mobile/ui.dart';

void main() {
  // A missing key only shows up at runtime as raw English; catch it here instead.
  test('every UI string has English and Bangla', () {
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join();
    final keys = RegExp(r"\bt\('([^'$]+)'\)").allMatches(source).map((m) => m[1]!).toSet();
    expect(keys.length, greaterThan(300));
    for (final lang in ['en', 'bn']) {
      session.lang = lang;
      for (final key in keys) {
        expect(() => t(key), returnsNormally, reason: key);
      }
    }
  });

  test('money, digits and Dhaka dates match the web', () {
    session.lang = 'en';
    expect(taka(1500), '৳1,500');
    expect(taka(500, 800), '৳500–800');
    expect(taka(500, 500), '৳500');
    expect(pay({'payAmount': 1200.7, 'paymentUnit': 'Day'}), '৳1,200 / day');
    expect(pay({'payAmount': 300, 'paymentUnit': 4}), '৳300 / project'); // offers send the unit as a number
    // 18:30 UTC is 00:30 the next day in Dhaka.
    expect(date('2026-10-10T18:30:00Z'), '11 Oct 2026, 12:30 AM');

    session.lang = 'bn';
    expect(taka(1500), '৳১,৫০০');
    expect(pay({'payAmount': 500, 'paymentUnit': 'Hour'}), '৳৫০০ / ঘণ্টা');
    expect(date('2026-10-10T06:05:00Z', time: false), '১০ অক্টো');
  });

  testWidgets('a job card shows title, pay and place', (tester) async {
    session.lang = 'en';
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(
        body: JobCard(job: {
          'id': '00000000-0000-0000-0000-000000000001',
          'title': 'Paint a two-room flat',
          'categoryEn': 'Painting',
          'categoryBn': 'রং',
          'workType': 'Task',
          'intake': 'Open',
          'locationMode': 'Physical',
          'areaEn': 'Mirpur',
          'districtEn': 'Dhaka',
          'payAmount': 4000,
          'paymentUnit': 'Project',
          'headcount': 2,
          'filledPositions': 0,
          'startsAt': '2026-10-12T04:00:00Z',
        }),
      ),
    ));
    expect(find.text('Paint a two-room flat'), findsOneWidget);
    expect(find.text('৳4,000 / project'), findsOneWidget);
    expect(find.text('Mirpur, Dhaka'), findsOneWidget);
    expect(find.text('2 people needed'), findsOneWidget);
  });
}
