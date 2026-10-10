import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import 'media.dart';

String rupees(double value) => '₹${value.toStringAsFixed(2)}';

String formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String initialOf(String name) =>
    name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

void showMessage(
  BuildContext context,
  String message, [
  SnackBarAction? action,
]) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

class NameAvatar extends StatelessWidget {
  const NameAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.photoPath,
  });

  final String name;
  final double radius;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = imageProviderFor(photoPath);

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      backgroundImage: image,
      child: image == null
          ? Text(
              initialOf(name),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}

class PhotoPicker extends StatelessWidget {
  const PhotoPicker({
    super.key,
    required this.label,
    required this.photoPath,
    required this.onChanged,
    this.radius = 36,
    this.icon,
  });

  final String label;
  final String? photoPath;
  final ValueChanged<String?> onChanged;
  final double radius;
  final IconData? icon;

  Future<void> _pick(BuildContext context) async {
    final picked = await choosePhoto(
      context,
      canRemove: photoPath != null && photoPath!.isNotEmpty,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = imageProviderFor(photoPath);

    return GestureDetector(
      onTap: () => _pick(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            backgroundImage: image,
            child: image == null
                ? Text(
                    initialOf(label),
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: Icon(icon ?? Icons.photo_camera_rounded, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

typedef PersonDetails = ({
  String name,
  String upi,
  String phone,
  String? photo,
});

Future<PersonDetails?> showPersonDialog(
  BuildContext context, {
  required String title,
  String name = '',
  String upi = '',
  String phone = '',
  String? photoPath,
  bool editName = true,
}) {
  return showDialog<PersonDetails>(
    context: context,
    builder: (_) => _PersonDialog(
      title: title,
      name: name,
      upi: upi,
      phone: phone,
      photoPath: photoPath,
      editName: editName,
    ),
  );
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({
    required this.title,
    required this.name,
    required this.upi,
    required this.phone,
    required this.photoPath,
    required this.editName,
  });

  final String title;
  final String name;
  final String upi;
  final String phone;
  final String? photoPath;
  final bool editName;

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.phone,
  );
  late final TextEditingController _upi = TextEditingController(
    text: widget.upi,
  );
  String? _photo;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _upi.dispose();
    super.dispose();
  }

  String? get _shownPhoto => _photo ?? widget.photoPath;

  Future<void> _pickContact() async {
    try {
      final contact = await FlutterNativeContactPicker().selectPhoneNumber();
      if (contact == null || !mounted) return;
      setState(() {
        if (widget.editName && (contact.fullName ?? '').isNotEmpty) {
          _name.text = contact.fullName!;
        }
        final number = contact.selectedPhoneNumber;
        if (number != null && number.isNotEmpty) _phone.text = number;
      });
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open your contacts');
    }
  }

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    Navigator.pop<PersonDetails>(context, (
      name: n,
      upi: _upi.text.trim(),
      phone: _phone.text.trim(),
      photo: _photo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhotoPicker(
              label: _name.text.isEmpty ? widget.name : _name.text,
              photoPath: _shownPhoto,
              onChanged: (value) => setState(() => _photo = value),
            ),
            if (widget.editName)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pickContact,
                  icon: const Icon(Icons.contacts_outlined, size: 18),
                  label: const Text('From contacts'),
                ),
              )
            else
              const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: widget.editName,
              autofocus: widget.editName,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                helperText: 'For SMS and WhatsApp',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upi,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                helperText: 'Optional',
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
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        widget.onChanged(value);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: _clear,
              ),
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

bool matchesQuery(String query, Iterable<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f.toLowerCase().contains(q));
}
