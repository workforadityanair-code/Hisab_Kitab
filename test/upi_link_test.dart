import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_kitab/upi.dart';

void main() {
  test('upi link carries the payee and the exact amount', () {
    final link = upiLink(upi: 'akhil@bank', name: 'Akhil K', amount: 625.5);
    final uri = Uri.parse(link);

    expect(uri.scheme, 'upi');
    expect(uri.host, 'pay');
    expect(uri.queryParameters['pa'], 'akhil@bank');
    expect(uri.queryParameters['pn'], 'Akhil K');
    expect(uri.queryParameters['am'], '625.50');
    expect(uri.queryParameters['cu'], 'INR');
  });

  test('upi link without an amount leaves the amount to the payer', () {
    final uri = Uri.parse(upiLink(upi: 'a@b', name: 'A'));
    expect(uri.queryParameters.containsKey('am'), isFalse);
  });
}
