import 'package:flutter/material.dart';

import 'messaging.dart';
import 'payment_qr.dart';
import 'widgets.dart';

Future<void> showSendMessageSheet(
  BuildContext context, {
  required String toName,
  required String phone,
  required String initialText,
  PaymentQr? qr,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MessageSheet(
      toName: toName,
      phone: phone,
      initialText: initialText,
      qr: qr,
    ),
  );
}

class _MessageSheet extends StatefulWidget {
  const _MessageSheet({
    required this.toName,
    required this.phone,
    required this.initialText,
    required this.qr,
  });

  final String toName;
  final String phone;
  final String initialText;
  final PaymentQr? qr;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  final _qrKey = GlobalKey();
  bool _attach = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send({required bool whatsapp}) async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      showMessage(context, 'Write a message first');
      return;
    }
    setState(() => _busy = true);

    var done = false;
    try {
      if (_attach) {
        final path = await capturePng(_qrKey);
        if (whatsapp) {
          done = await sendWhatsAppImage(
            phone: widget.phone,
            text: text,
            path: path,
          );
        }
        if (!done) {
          await shareImage(path: path, text: text);
          done = true;
        }
      } else {
        done = whatsapp
            ? await sendWhatsApp(widget.phone, text)
            : await sendSms(widget.phone, text);
      }
    } catch (_) {
      done = false;
    }

    if (!mounted) return;
    if (done) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        'Could not open ${whatsapp ? 'WhatsApp' : 'messages'}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qr = widget.qr;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Message ${widget.toName}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              widget.phone,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            if (qr != null) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _attach,
                onChanged: (v) => setState(() => _attach = v),
                title: const Text('Attach payment QR'),
                subtitle: Text(
                  qr.amount == null
                      ? 'They can scan it to pay you'
                      : 'Exact amount ${rupees(qr.amount!)} is filled in',
                ),
              ),
              if (_attach)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RepaintBoundary(
                      key: _qrKey,
                      child: PaymentQrCard(qr: qr),
                    ),
                  ),
                ),
              if (_attach)
                Text(
                  'WhatsApp opens the chat with the image attached. '
                  'SMS opens your share sheet because texts cannot carry images.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _send(whatsapp: false),
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('SMS'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _send(whatsapp: true),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
