import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets.dart';

const _channel = MethodChannel('hisabkitab/share');

String _international(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length == 10 ? '91$digits' : digits;
}

Future<bool> _open(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> sendSms(String phone, String text) => _open(
  Uri.parse('sms:+${_international(phone)}?body=${Uri.encodeComponent(text)}'),
);

Future<bool> sendWhatsApp(String phone, String text) => _open(
  Uri.parse(
    'https://wa.me/${_international(phone)}?text=${Uri.encodeComponent(text)}',
  ),
);

Future<bool> sendWhatsAppImage({
  required String phone,
  required String text,
  required String path,
}) async {
  try {
    final ok = await _channel.invokeMethod<bool>('whatsappImage', {
      'path': path,
      'text': text,
      'phone': _international(phone),
    });
    return ok ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Future<void> shareImage({required String path, required String text}) async {
  await SharePlus.instance.share(ShareParams(text: text, files: [XFile(path)]));
}

Future<void> shareHisabFile({
  required String path,
  required String text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile(path, mimeType: 'application/x-hisab')],
    ),
  );
}

String reminderMessage({
  required String to,
  required String from,
  required double amount,
  required String group,
  required String upi,
}) {
  final pay = upi.isEmpty ? '' : ' Pay via UPI to $upi.';
  return 'Hi $to, reminder: you owe $from ${rupees(amount)} for "$group" '
      'on HisabKitab.$pay';
}

String paidMessage({
  required String to,
  required double amount,
  required String group,
}) => 'Hi $to, I have paid you ${rupees(amount)} for "$group" on HisabKitab.';
