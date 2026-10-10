import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'hisab_file.dart';
import 'messaging.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> shareGroupFile(BuildContext context, ExpenseGroup group) async {
  try {
    final file = await writeHisabFile(group.name, buildGroupFile(group));
    await shareHisabFile(
      path: file.path,
      text:
          'Open this file in HisabKitab to load "${group.name}" with all '
          'its expenses.',
    );
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not create the file');
  }
}

Future<void> shareBackupFile(BuildContext context) async {
  try {
    final stamp = DateTime.now();
    final file = await writeHisabFile(
      'HisabKitab backup ${stamp.year}-${stamp.month}-${stamp.day}',
      buildBackupFile(),
    );
    await shareHisabFile(
      path: file.path,
      text: 'HisabKitab backup. Save this file somewhere safe.',
    );
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not create the backup');
  }
}

Future<String?> pickAndImportHisab(BuildContext context) async {
  final files = await FilePicker.pickFiles(type: FileType.any);
  if (files.isEmpty) return null;
  final path = files.first.path;
  if (path == null) {
    if (context.mounted) showMessage(context, 'Could not read that file');
    return null;
  }

  String text;
  try {
    text = await File(path).readAsString();
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not read that file');
    return null;
  }
  if (!context.mounted) return null;
  return importHisabText(context, text);
}

Future<String?> importHisabText(BuildContext context, String text) async {
  final HisabPackage package;
  try {
    package = parseHisabFile(text);
  } on HisabFormatException catch (e) {
    showMessage(context, e.message);
    return null;
  }

  if (package.isBackup) {
    await _restoreFlow(context, package);
    return null;
  }
  return _groupFlow(context, package);
}

Future<void> _restoreFlow(BuildContext context, HisabPackage package) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Restore this backup?'),
      content: Text(
        'This backup is from ${package.senderName}, made on '
        '${formatDate(package.exportedAt)}, with ${package.groups.length} '
        'groups and ${package.expenses.length} expenses.\n\n'
        'Everything currently on this phone will be replaced.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Replace and restore'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await restoreBackup(package);
  if (context.mounted) showMessage(context, 'Backup restored');
}

Future<String?> _groupFlow(BuildContext context, HisabPackage package) async {
  final candidates = candidateNames(package);
  final chosen = await showDialog<_ImportChoice>(
    context: context,
    builder: (_) => _GroupImportDialog(
      package: package,
      candidates: candidates,
      initial: detectMe(package),
      existingCount: countExisting(package),
    ),
  );
  if (chosen == null) return null;

  final summary = await importGroup(package, chosenMeId: chosen.meId);
  if (context.mounted) {
    showMessage(
      context,
      '${summary.added} added, ${summary.updated} updated in '
      '"${package.groupName}"',
    );
  }
  return summary.groupId;
}

class _ImportChoice {
  const _ImportChoice(this.meId);

  final String? meId;
}

class _GroupImportDialog extends StatefulWidget {
  const _GroupImportDialog({
    required this.package,
    required this.candidates,
    required this.initial,
    required this.existingCount,
  });

  final HisabPackage package;
  final Map<String, String> candidates;
  final String? initial;
  final int existingCount;

  @override
  State<_GroupImportDialog> createState() => _GroupImportDialogState();
}

class _GroupImportDialogState extends State<_GroupImportDialog> {
  late String? _me = widget.initial;

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final theme = Theme.of(context);
    final alreadyHere = widget.existingCount > 0;
    final autoDetected = widget.initial != null;

    return AlertDialog(
      title: Text('Load "${package.groupName}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared by ${package.senderName} on '
              '${formatDate(package.exportedAt)}.\n'
              '${package.expenses.length} expenses, '
              '${widget.candidates.length} people.',
            ),
            if (alreadyHere) ...[
              const SizedBox(height: 8),
              Text(
                '${widget.existingCount} of these are already on your phone '
                'and will be updated.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              autoDetected ? 'You are' : 'Which one is you?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            RadioGroup<String?>(
              groupValue: _me,
              onChanged: (v) => setState(() => _me = v),
              child: Column(
                children: [
                  for (final entry in widget.candidates.entries)
                    RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: entry.key,
                      title: Text(
                        entry.key == appStore.profileId
                            ? '${entry.value} (you)'
                            : entry.value,
                      ),
                    ),
                  const RadioListTile<String?>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: null,
                    title: Text('None of them, add me as new'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ImportChoice(_me)),
          child: const Text('Load group'),
        ),
      ],
    );
  }
}
