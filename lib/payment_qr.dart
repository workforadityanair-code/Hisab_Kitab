import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'upi.dart';
import 'widgets.dart';

class PaymentQr {
  const PaymentQr({required this.name, required this.upi, this.amount});

  final String name;
  final String upi;
  final double? amount;
}

class PaymentQrCard extends StatelessWidget {
  const PaymentQrCard({super.key, required this.qr});

  final PaymentQr qr;

  @override
  Widget build(BuildContext context) {
    final amount = qr.amount;

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: upiLink(upi: qr.upi, name: qr.name, amount: amount),
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE0E0E0), height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 28,
                    height: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HisabKitab',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Paying ${qr.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (amount != null) ...[
              const SizedBox(height: 4),
              Text(
                rupees(amount),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              qr.upi,
              style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String> capturePng(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(
    '${Directory.systemTemp.path}/hisabkitab_qr_'
    '${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file.path;
}
