import 'dart:math';

class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

class ParsedItem {
  const ParsedItem(this.name, this.amount);

  final String name;
  final double amount;
}

class ParsedBill {
  const ParsedBill({
    required this.items,
    required this.taxAmount,
    required this.taxPercent,
    required this.detectedTotal,
  });

  final List<ParsedItem> items;
  final double taxAmount;
  final double taxPercent;
  final double? detectedTotal;

  double get itemsTotal => items.fold(0.0, (sum, i) => sum + i.amount);
}

const _standardSlabs = [0.0, 2.5, 5.0, 6.0, 9.0, 10.0, 12.0, 14.0, 18.0, 28.0];

final _amountPattern = RegExp(r'^(\d{1,3}(,\d{2,3})+|\d+)(\.\d{1,2})?$');
final _numericLike = RegExp(r'^([\d.,]+|[xX]\d+|\d+[xX]|[@*xX])$');
final _smallInteger = RegExp(r'^\d{1,3}[.)]?$');

RegExp _words(List<String> words) =>
    RegExp(r'\b(' + words.map(RegExp.escape).join('|') + r')\b');

final _ignoreRow = _words([
  'gstin',
  'gst no',
  'invoice',
  'bill no',
  'bill number',
  'phone',
  'tel',
  'mob',
  'mobile',
  'date',
  'time',
  'table',
  'order no',
  'token',
  'fssai',
  'cashier',
  'pan',
  'customer',
  'thank you',
  'visit',
]);
final _paymentRow = _words([
  'cash',
  'card',
  'upi',
  'paid',
  'tendered',
  'change',
  'wallet',
  'paytm',
  'gpay',
  'phonepe',
]);
final _roundingRow = _words(['round off', 'rounding', 'round', 'roundoff']);
final _subtotalRow = _words([
  'sub total',
  'subtotal',
  'sub-total',
  'item total',
]);
final _taxRow = _words([
  'cgst',
  'sgst',
  'igst',
  'gst',
  'vat',
  'service charge',
  'service tax',
  's charge',
  'tax',
  'cess',
  'surcharge',
]);
final _discountRow = _words(['discount', 'disc', 'coupon', 'promo', 'saving']);
final _totalRow = _words([
  'grand total',
  'net total',
  'net amount',
  'amount payable',
  'bill amount',
  'total amount',
  'amount due',
  'total',
  'payable',
]);
final _totalWord = RegExp(r'\btotal\b');

List<String> buildRows(List<OcrLine> lines) {
  if (lines.isEmpty) return [];

  final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final heights = sorted.map((l) => l.height).toList()..sort();
  final tolerance = max(6.0, heights[heights.length ~/ 2] * 0.6);

  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    if (rows.isNotEmpty) {
      final row = rows.last;
      final average = row.fold(0.0, (s, l) => s + l.centerY) / row.length;
      if ((line.centerY - average).abs() <= tolerance) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }

  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left)))
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join(' '),
  ];
}

String _cleanToken(String token) {
  var t = token.trim();
  t = t.replaceFirst(RegExp(r'^(₹|rs\.?|inr)', caseSensitive: false), '');
  t = t.replaceFirst(RegExp(r'(/-|-)$'), '');
  if (t.endsWith('.') && t.length > 1) t = t.substring(0, t.length - 1);
  return t;
}

double? _asAmount(String token) {
  final t = _cleanToken(token);
  if (t.isEmpty || !_amountPattern.hasMatch(t)) return null;
  return double.tryParse(t.replaceAll(',', ''));
}

class _Row {
  const _Row(this.name, this.amount);

  final String name;
  final double amount;
}

_Row? _splitRow(String text) {
  final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.length < 2) return null;

  var priceIndex = tokens.length - 1;
  if (_asAmount(tokens[priceIndex]) == null &&
      tokens[priceIndex].length <= 2 &&
      priceIndex > 0 &&
      _asAmount(tokens[priceIndex - 1]) != null) {
    priceIndex -= 1;
  }
  final amount = _asAmount(tokens[priceIndex]);
  if (amount == null) return null;

  var start = 0;
  final head = tokens.sublist(0, priceIndex);
  if (head.length > 1 && _smallInteger.hasMatch(head.first)) start = 1;

  final nameTokens = <String>[];
  for (var i = start; i < head.length; i++) {
    if (_numericLike.hasMatch(head[i]) && nameTokens.isNotEmpty) break;
    if (_numericLike.hasMatch(head[i])) continue;
    nameTokens.add(head[i]);
  }

  final name = nameTokens
      .join(' ')
      .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9)]+$'), '')
      .trim();
  return _Row(name, amount);
}

int _letters(String text) => RegExp(r'[A-Za-z]').allMatches(text).length;

ParsedBill parseBill(List<List<OcrLine>> pages) {
  final rows = [for (final page in pages) ...buildRows(page)];

  final items = <ParsedItem>[];
  var taxParts = 0.0;
  var totalTax = 0.0;
  double? detectedTotal;
  var inFooter = false;

  for (final raw in rows) {
    final text = raw.toLowerCase();
    final row = _splitRow(raw);
    if (row == null) continue;
    if (_ignoreRow.hasMatch(text) || _paymentRow.hasMatch(text)) continue;
    if (_roundingRow.hasMatch(text)) continue;

    if (_subtotalRow.hasMatch(text)) {
      inFooter = true;
      continue;
    }
    if (_taxRow.hasMatch(text)) {
      inFooter = true;
      if (_totalWord.hasMatch(text)) {
        totalTax = max(totalTax, row.amount);
      } else {
        taxParts += row.amount;
      }
      continue;
    }
    if (_discountRow.hasMatch(text)) {
      items.add(ParsedItem('Discount', -row.amount));
      continue;
    }
    if (_totalRow.hasMatch(text)) {
      inFooter = true;
      detectedTotal = max(detectedTotal ?? 0, row.amount);
      continue;
    }
    if (inFooter) continue;
    if (_letters(row.name) < 2 || row.amount <= 0 || row.amount >= 1000000) {
      continue;
    }
    items.add(ParsedItem(row.name, row.amount));
  }

  final taxAmount = totalTax > 0 ? totalTax : taxParts;
  final itemsTotal = items.fold(0.0, (sum, i) => sum + i.amount);
  var taxPercent = 0.0;
  if (taxAmount > 0 && itemsTotal > 0) {
    taxPercent = double.parse(
      (taxAmount / itemsTotal * 100).toStringAsFixed(2),
    );
    for (final slab in _standardSlabs) {
      if ((taxPercent - slab).abs() < 0.25) {
        taxPercent = slab;
        break;
      }
    }
  }

  return ParsedBill(
    items: items,
    taxAmount: taxAmount,
    taxPercent: taxPercent,
    detectedTotal: detectedTotal,
  );
}
