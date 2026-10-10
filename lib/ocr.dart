import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'bill_parser.dart';

Future<List<OcrLine>> recognizeLines(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrLine(
            line.text,
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.right,
            line.boundingBox.bottom,
          ),
    ];
  } finally {
    await recognizer.close();
  }
}
