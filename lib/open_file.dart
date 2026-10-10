import 'package:flutter/services.dart';

const _channel = MethodChannel('hisabkitab/share');

Future<String?> takeOpenedFile() async {
  try {
    return await _channel.invokeMethod<String>('takeOpenedFile');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

void listenForOpenedFiles(void Function(String text) onFile) {
  _channel.setMethodCallHandler((call) async {
    if (call.method != 'fileOpened') return;
    final text = await takeOpenedFile();
    if (text != null) onFile(text);
  });
}
