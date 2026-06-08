import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:calora/main.dart';
import 'package:calora/providers/diary_provider.dart';

void main() {
  testWidgets('app renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DiaryProvider(),
        child: const CaloraApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
