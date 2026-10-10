import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

import 'bill_parser.dart';
import 'bill_review_screen.dart';
import 'models.dart';
import 'ocr.dart';
import 'widgets.dart';

String _asPath(String value) =>
    value.startsWith('file://') ? Uri.parse(value).toFilePath() : value;

Future<List<String>?> _cameraFallback() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );
  return picked == null ? null : [picked.path];
}

Future<List<String>?> _capture() async {
  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormats: {DocumentFormat.jpeg},
      mode: ScannerMode.full,
      pageLimit: 3,
      isGalleryImport: true,
    ),
  );
  try {
    final result = await scanner.scanDocument();
    final images = result.images ?? const <String>[];
    return images.isEmpty ? null : images.map(_asPath).toList();
  } on PlatformException catch (e) {
    final cancelled = (e.message ?? '').toLowerCase().contains('cancel');
    return cancelled ? null : _cameraFallback();
  } on MissingPluginException {
    return _cameraFallback();
  } finally {
    await scanner.close().catchError((_) {});
  }
}

Future<void> startBillScan(
  BuildContext context,
  ExpenseGroup group, {
  bool replace = false,
}) async {
  final paths = await _capture();
  if (paths == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Reading your bill')),
          ],
        ),
      ),
    ),
  );

  ParsedBill? parsed;
  try {
    final pages = <List<OcrLine>>[];
    for (final path in paths) {
      pages.add(await recognizeLines(path));
    }
    parsed = parseBill(pages);
  } catch (_) {
    parsed = null;
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (parsed == null || parsed.items.isEmpty) {
    showMessage(context, 'Could not read any items. You can add them by hand.');
  }

  final route = MaterialPageRoute<void>(
    builder: (_) => BillReviewScreen(
      group: group,
      parsed: parsed,
      scannedPath: paths.first,
    ),
  );
  if (replace) {
    await Navigator.pushReplacement(context, route);
  } else {
    await Navigator.push(context, route);
  }
}
