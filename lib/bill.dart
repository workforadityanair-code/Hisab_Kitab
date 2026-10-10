import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'categories.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

Future<Uint8List> buildGroupBill(ExpenseGroup group) async {
  final logoBytes = await rootBundle.load('assets/icon/app_icon.png');
  final fontBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final font = pw.Font.ttf(fontBytes);
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );

  final all = appStore.expensesFor(group.id).reversed.toList();
  final bills = all.where((e) => !e.isSettlement).toList();
  final payments = all.where((e) => e.isSettlement).toList();
  final members = appStore.membersOf(group);
  final balances = appStore.balancesFor(group);
  final settlements = appStore.settlementsFor(group);
  final total = bills.fold(0.0, (sum, e) => sum + e.amount);
  final totalTax = bills.fold(0.0, (sum, e) => sum + e.taxAmount);
  final grey = PdfColors.grey700;

  String name(String id) => appStore.nameOf(id);

  Uint8List? receiptBytes(GroupExpense e) {
    final path = e.receiptPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  final heading = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Row(
          children: [
            pw.SizedBox(width: 56, height: 56, child: pw.Image(logo)),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'HisabKitab',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Bill for ${group.name}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.Text(
                    'Generated ${formatDate(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10, color: grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text('Summary', style: heading),
        pw.SizedBox(height: 4),
        pw.Text(
          'Total spent: ${rupees(total)} across ${bills.length} '
          '${bills.length == 1 ? 'expense' : 'expenses'}',
        ),
        if (totalTax > 0.005) pw.Text('Of which tax: ${rupees(totalTax)}'),
        pw.Text('Members: ${members.map((m) => m.name).join(', ')}'),
        pw.SizedBox(height: 16),
        pw.Text('Expenses', style: heading),
        if (bills.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('No expenses yet', style: pw.TextStyle(color: grey)),
          ),
        for (final e in bills) ...[
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                e.title,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                rupees(e.amount),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Text(
            '${formatDate(e.createdAt)} • Paid by ${name(e.paidBy)}'
            '${e.category.isEmpty ? '' : ' • ${categoryOf(e.category).label}'}',
            style: pw.TextStyle(fontSize: 9, color: grey),
          ),
          pw.SizedBox(height: 4),
          if (e.items.isNotEmpty) ...[
            pw.TableHelper.fromTextArray(
              headers: const ['Item', 'Amount', 'Shared by'],
              data: [
                for (final item in e.items)
                  [
                    item.name,
                    rupees(item.amount),
                    item.sharedBy.map(name).join(', '),
                  ],
              ],
              cellAlignments: {1: pw.Alignment.centerRight},
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(3),
              },
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 4),
          ],
          if (e.taxPercent > 0)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Subtotal ${rupees(e.subtotal)}   '
                'Tax (${_percent(e.taxPercent)}%) ${rupees(e.taxAmount)}   '
                'Total ${rupees(e.amount)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: [
              'Person',
              e.taxPercent > 0 ? 'Share (incl. tax)' : 'Share',
            ],
            data: [
              for (final entry
                  in (e.splitShares.entries.toList()
                    ..sort((a, b) => name(a.key).compareTo(name(b.key)))))
                [name(entry.key), rupees(entry.value)],
            ],
            cellAlignments: {1: pw.Alignment.centerRight},
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300),
          ),
          if (receiptBytes(e) case final bytes?) ...[
            pw.SizedBox(height: 6),
            pw.Text('Receipt', style: pw.TextStyle(fontSize: 9, color: grey)),
            pw.SizedBox(height: 2),
            pw.Image(pw.MemoryImage(bytes), width: 140),
          ],
        ],
        if (payments.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Payments recorded', style: heading),
          pw.SizedBox(height: 4),
          for (final p in payments)
            pw.Text(
              '${formatDate(p.createdAt)}: ${name(p.paidBy)} paid '
              '${name(p.splitShares.keys.first)} ${rupees(p.amount)}',
            ),
        ],
        pw.SizedBox(height: 16),
        pw.Text('Balances', style: heading),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: const ['Person', 'Paid', 'Share', 'Net'],
          data: [
            for (final m in members)
              [
                m.name,
                rupees(_paidBy(bills, m.id)),
                rupees(_shareOf(bills, m.id)),
                _signed(balances[m.id] ?? 0),
              ],
          ],
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          border: pw.TableBorder.all(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Who pays whom', style: heading),
        pw.SizedBox(height: 4),
        if (settlements.isEmpty)
          pw.Text('Everyone is settled up')
        else
          for (final s in settlements)
            pw.Text(
              '${name(s.debtor)} pays ${name(s.creditor)} ${rupees(s.amount)}',
            ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Generated with HisabKitab',
          style: pw.TextStyle(fontSize: 9, color: grey),
        ),
      ],
    ),
  );

  return doc.save();
}

double _paidBy(List<GroupExpense> bills, String id) =>
    bills.where((e) => e.paidBy == id).fold(0.0, (sum, e) => sum + e.amount);

double _shareOf(List<GroupExpense> bills, String id) =>
    bills.fold(0.0, (sum, e) => sum + (e.splitShares[id] ?? 0));

String _signed(double value) {
  if (value.abs() < 0.005) return 'settled';
  return '${value > 0 ? '+' : '-'}${rupees(value.abs())}';
}

String _percent(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
