import 'package:flutter/material.dart';

import 'messaging.dart';
import 'payment_qr.dart';
import 'widgets.dart';

class UpiQrScreen extends StatefulWidget {
  const UpiQrScreen({
    super.key,
    required this.name,
    required this.upi,
    this.amount,
  });

  final String name;
  final String upi;
  final double? amount;

  @override
  State<UpiQrScreen> createState() => _UpiQrScreenState();
}

class _UpiQrScreenState extends State<UpiQrScreen> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final path = await capturePng(_key);
      final amount = widget.amount;
      await shareImage(
        path: path,
        text: amount == null
            ? 'Pay ${widget.name} on UPI: ${widget.upi}'
            : 'Pay ${widget.name} ${rupees(amount)} on UPI: ${widget.upi}',
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not share the QR');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment QR')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _key,
                child: PaymentQrCard(
                  qr: PaymentQr(
                    name: widget.name,
                    upi: widget.upi,
                    amount: widget.amount,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.amount == null
                    ? 'Scan with any UPI app to pay'
                    : 'Scan with any UPI app. The amount is already filled in.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share as image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
