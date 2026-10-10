import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

Future<Directory> _folder(String name) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/$name');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String> saveImageCopy(String source, String folder) async {
  final dir = await _folder(folder);
  final dest = '${dir.path}/${newId()}.jpg';
  await File(source).copy(dest);
  return dest;
}

Future<String?> saveBase64Image(String data, String folder) async {
  try {
    final dir = await _folder(folder);
    final dest = '${dir.path}/${newId()}.jpg';
    await File(dest).writeAsBytes(base64Decode(data));
    return dest;
  } catch (_) {
    return null;
  }
}

String? readBase64Image(String? path) {
  if (path == null) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return base64Encode(file.readAsBytesSync());
}

ImageProvider? imageProviderFor(String? path) {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  return file.existsSync() ? FileImage(file) : null;
}

const removePhoto = '';

Future<String?> commitPhoto(
  String? picked,
  String? current,
  String folder,
) async {
  if (picked == null) return current;
  if (picked == removePhoto) return null;
  return saveImageCopy(picked, folder);
}

enum _PhotoChoice { camera, gallery, remove }

Future<String?> choosePhoto(
  BuildContext context, {
  bool canRemove = false,
}) async {
  final choice = await showModalBottomSheet<_PhotoChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, _PhotoChoice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, _PhotoChoice.gallery),
          ),
          if (canRemove)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove photo'),
              onTap: () => Navigator.pop(ctx, _PhotoChoice.remove),
            ),
        ],
      ),
    ),
  );

  if (choice == null) return null;
  if (choice == _PhotoChoice.remove) return removePhoto;

  final picked = await ImagePicker().pickImage(
    source: choice == _PhotoChoice.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 80,
  );
  return picked?.path;
}
