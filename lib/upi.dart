import 'package:url_launcher/url_launcher.dart';

String upiLink({required String upi, required String name, double? amount}) {
  final amountPart = amount == null ? '' : '&am=${amount.toStringAsFixed(2)}';
  return 'upi://pay?pa=${Uri.encodeComponent(upi)}'
      '&pn=${Uri.encodeComponent(name)}$amountPart'
      '&cu=INR&tn=HisabKitab%20Settlement';
}

Future<bool> launchUpiPayment({
  required String upi,
  required String name,
  required double amount,
}) async {
  try {
    return await launchUrl(
      Uri.parse(upiLink(upi: upi, name: name, amount: amount)),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
