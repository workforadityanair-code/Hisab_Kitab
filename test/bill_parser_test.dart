import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_kitab/bill_parser.dart';

List<OcrLine> _page(List<(String, String?)> rows) {
  final lines = <OcrLine>[];
  for (var i = 0; i < rows.length; i++) {
    final top = 20.0 + i * 40;
    lines.add(OcrLine(rows[i].$1, 10, top, 300, top + 20));
    final price = rows[i].$2;
    if (price != null) lines.add(OcrLine(price, 400, top + 2, 480, top + 22));
  }
  return lines;
}

void main() {
  test('parses restaurant items, tax and total', () {
    final bill = parseBill([
      _page([
        ('SPICE GARDEN RESTAURANT', null),
        ('Ph: 9876543210', null),
        ('Date: 10/10/2026', null),
        ('1 Paneer Tikka', '280.00'),
        ('2 x Butter Naan', '90.00'),
        ('Masala Dosa', '160'),
        ('Cashew Nut Curry', '1,250.00'),
        ('Sub Total', '1780.00'),
        ('CGST @ 2.5%', '44.50'),
        ('SGST @ 2.5%', '44.50'),
        ('Grand Total', '1869.00'),
        ('Paid by Card', '1869.00'),
      ]),
    ]);

    expect(bill.items.map((i) => i.name), [
      'Paneer Tikka',
      'Butter Naan',
      'Masala Dosa',
      'Cashew Nut Curry',
    ]);
    expect(bill.items.map((i) => i.amount), [280, 90, 160, 1250]);
    expect(bill.taxAmount, closeTo(89, 0.001));
    expect(bill.taxPercent, 5.0);
    expect(bill.detectedTotal, closeTo(1869, 0.001));
  });

  test('uses a combined tax row instead of double counting', () {
    final bill = parseBill([
      _page([
        ('Veg Biryani', '200.00'),
        ('Lassi', '100.00'),
        ('CGST 9%', '27.00'),
        ('SGST 9%', '27.00'),
        ('Total GST', '54.00'),
        ('Total', '354.00'),
      ]),
    ]);

    expect(bill.taxAmount, closeTo(54, 0.001));
    expect(bill.taxPercent, 18.0);
  });

  test('keeps discounts as negative items', () {
    final bill = parseBill([
      _page([('Pizza', '400.00'), ('Discount', '50.00'), ('Total', '350.00')]),
    ]);

    expect(bill.items.last.name, 'Discount');
    expect(bill.items.last.amount, -50);
    expect(bill.itemsTotal, closeTo(350, 0.001));
  });

  test('joins name and price that arrive as separate OCR lines', () {
    final bill = parseBill([
      [
        const OcrLine('Cold Coffee', 10, 100, 200, 120),
        const OcrLine('150.00', 420, 103, 490, 123),
        const OcrLine('Brownie', 10, 150, 200, 170),
        const OcrLine('120.00', 420, 151, 490, 171),
      ],
    ]);

    expect(bill.items.length, 2);
    expect(bill.items.first.name, 'Cold Coffee');
    expect(bill.items.first.amount, 150);
  });

  test('returns nothing for text with no prices', () {
    final bill = parseBill([
      _page([('Welcome', null), ('Have a nice day', null)]),
    ]);
    expect(bill.items, isEmpty);
    expect(bill.taxAmount, 0);
  });

  test('reads several pages in order', () {
    final bill = parseBill([
      _page([('Soup', '120.00')]),
      _page([('Dessert', '180.00'), ('Total', '300.00')]),
    ]);
    expect(bill.items.map((i) => i.name), ['Soup', 'Dessert']);
    expect(bill.detectedTotal, 300);
  });
}
