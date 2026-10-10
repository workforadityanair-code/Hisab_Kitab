import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'settings.dart';
import 'store.dart';

Future<bool> deviceCanAuthenticate() async {
  try {
    return await LocalAuthentication().isDeviceSupported();
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateUser(String reason) async {
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: reason,
      persistAcrossBackgrounding: true,
    );
  } catch (_) {
    return false;
  }
}

class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = appSettings.appLock;
  DateTime? _pausedAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    appStore.applyDueRecurring();

    final away = _pausedAt;
    _pausedAt = null;
    if (!appSettings.appLock || away == null || _locked) return;
    final seconds = DateTime.now().difference(away).inSeconds;
    if (seconds >= appSettings.lockAfterSeconds) {
      setState(() => _locked = true);
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    try {
      final supported = await deviceCanAuthenticate();
      final ok = !supported || await authenticateUser('Unlock HisabKitab');
      if (ok && mounted) setState(() => _locked = false);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              color: scheme.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 56,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'HisabKitab is locked',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
