import 'package:flutter/material.dart';

import 'media.dart';
import 'store.dart';
import 'upi_qr_screen.dart';
import 'widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _upi;
  late final TextEditingController _phone;
  String? _photo;
  String? _error;

  @override
  void initState() {
    super.initState();
    final me = appStore.hasProfile ? appStore.me : null;
    _name = TextEditingController(text: me?.name ?? '');
    _upi = TextEditingController(text: me?.upi ?? '');
    _phone = TextEditingController(text: me?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _upi.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _shownPhoto =>
      _photo ?? (appStore.hasProfile ? appStore.me.photoPath : null);

  Future<void> _save() async {
    final name = _name.text.trim();
    final upi = _upi.text.trim();
    final phone = _phone.text.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (upi.isNotEmpty && !upi.contains('@')) {
      setState(() => _error = 'UPI ID should look like name@bank');
      return;
    }
    if (phone.isNotEmpty && digits.length < 10) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }

    final current = appStore.hasProfile ? appStore.me.photoPath : null;
    final photo = await commitPhoto(_photo, current, 'people');
    await appStore.saveProfile(name: name, upi: upi, phone: phone);
    if (photo != current) appStore.setPersonPhoto(appStore.me, photo);
    if (!mounted || widget.firstRun) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.firstRun
          ? null
          : AppBar(title: const Text('Your profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.firstRun) ...[
              const SizedBox(height: 24),
              Image.asset('assets/icon/app_icon.png', width: 72, height: 72),
              const SizedBox(height: 24),
              Text(
                'Welcome to HisabKitab',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Set up your profile once. Friends see your UPI ID and phone '
                'number when you ask to be paid.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: PhotoPicker(
                    label: _name.text.isEmpty ? 'You' : _name.text,
                    photoPath: _shownPhoto,
                    radius: 44,
                    onChanged: (v) => setState(() => _photo = v),
                  ),
                ),
              ),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                helperText: 'Used for SMS and WhatsApp messages',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _upi,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'name@bank',
                helperText: 'Friends use this to pay you',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(widget.firstRun ? 'Continue' : 'Save'),
            ),
            if (!widget.firstRun && _upi.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UpiQrScreen(
                      name: _name.text.trim(),
                      upi: _upi.text.trim(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Show my UPI QR'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
