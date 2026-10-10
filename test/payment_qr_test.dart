import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_kitab/payment_qr.dart';

void main() {
  testWidgets('payment card renders to a PNG with name and amount', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const PaymentQrCard(
                qr: PaymentQr(name: 'Akhil', upi: 'akhil@bank', amount: 625.25),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        tester.element(find.byType(PaymentQrCard)),
      );
    });
    await tester.pumpAndSettle();

    final path = await tester.runAsync(() => capturePng(key));
    final file = File(path!);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(2000));
    file.copySync('${Directory.systemTemp.path}/hk_qr_card.png');
    expect(find.text('Paying Akhil'), findsOneWidget);
    expect(find.text('₹625.25'), findsOneWidget);
  });
}
