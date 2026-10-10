import 'package:flutter/material.dart';

import 'app_info.dart';
import 'import_flow.dart';
import 'insights_screen.dart';
import 'lock_gate.dart';
import 'recurring_screen.dart';
import 'settings.dart';
import 'setup_screen.dart';
import 'store.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appSettings, appStore]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _profile(context),
            _section(context, 'Appearance'),
            _appearance(context),
            _section(context, 'Security'),
            _security(context),
            _section(context, 'Expenses'),
            _expenses(context),
            _section(context, 'Data'),
            _data(context),
            _section(context, 'About'),
            _about(context),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _profile(BuildContext context) {
    final me = appStore.hasProfile ? appStore.me : null;
    final details = [
      if (me != null && me.phone.isNotEmpty) me.phone,
      if (me != null && me.upi.isNotEmpty) me.upi,
    ].join(' • ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: NameAvatar(
        name: appStore.meName,
        photoPath: me?.photoPath,
        radius: 28,
      ),
      title: Text(
        appStore.meName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(details.isEmpty ? 'Add your UPI ID and phone' : details),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      ),
    );
  }

  Widget _appearance(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {appSettings.themeMode},
              onSelectionChanged: (s) =>
                  appSettings.update((v) => v.themeMode = s.first),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('Use wallpaper colors'),
          subtitle: const Text('Material You, on Android 12 and above'),
          value: appSettings.useDynamicColor,
          onChanged: (v) => appSettings.update((s) => s.useDynamicColor = v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              appSettings.useDynamicColor
                  ? 'Accent color (used when wallpaper colors are unavailable)'
                  : 'Accent color',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < accentColors.length; i++)
                GestureDetector(
                  onTap: () => appSettings.update((s) => s.accentIndex = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: appSettings.accentIndex == i
                            ? scheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: appSettings.accentIndex == i
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _security(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('App lock'),
          subtitle: const Text('Ask for fingerprint, face or screen lock'),
          value: appSettings.appLock,
          onChanged: (on) async {
            if (!on) {
              appSettings.update((s) => s.appLock = false);
              return;
            }
            if (!await deviceCanAuthenticate()) {
              if (context.mounted) {
                showMessage(
                  context,
                  'Set a screen lock on this phone to use app lock',
                );
              }
              return;
            }
            final ok = await authenticateUser('Confirm to turn on app lock');
            if (ok) appSettings.update((s) => s.appLock = true);
          },
        ),
        if (appSettings.appLock)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Lock after'),
            trailing: DropdownButton<int>(
              value: appSettings.lockAfterSeconds,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Immediately')),
                DropdownMenuItem(value: 30, child: Text('30 seconds')),
                DropdownMenuItem(value: 300, child: Text('5 minutes')),
              ],
              onChanged: (v) => appSettings.update(
                (s) => s.lockAfterSeconds = v ?? s.lockAfterSeconds,
              ),
            ),
          ),
      ],
    );
  }

  Widget _expenses(BuildContext context) {
    const taxChoices = [0.0, 5.0, 12.0, 18.0, 28.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text('Default tax for new expenses'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in taxChoices)
                ChoiceChip(
                  label: Text(t == 0 ? 'None' : '${t.toStringAsFixed(0)}%'),
                  selected: appSettings.defaultTax == t,
                  onSelected: (_) =>
                      appSettings.update((s) => s.defaultTax = t),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('Split by exact amounts by default'),
          subtitle: const Text('Otherwise expenses split equally'),
          value: appSettings.defaultExactSplit,
          onChanged: (v) => appSettings.update((s) => s.defaultExactSplit = v),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('Message signature'),
          subtitle: Text(
            appSettings.signature.isEmpty
                ? 'Added to the end of reminders'
                : appSettings.signature,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editSignature(context),
        ),
      ],
    );
  }

  Future<void> _editSignature(BuildContext context) async {
    final controller = TextEditingController(text: appSettings.signature);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message signature'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Signature',
            hintText: 'Thanks, Aditya',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) appSettings.update((s) => s.signature = value);
  }

  Widget _data(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.insights_rounded),
          title: const Text('Insights'),
          subtitle: const Text('Monthly spending by category'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InsightsScreen()),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.event_repeat_rounded),
          title: const Text('Recurring expenses'),
          subtitle: Text('${appStore.recurring.length} active'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecurringScreen()),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Load a .hisab file'),
          subtitle: const Text('A shared group or a backup'),
          onTap: () async {
            final groupId = await pickAndImportHisab(context);
            if (groupId != null && context.mounted) {
              Navigator.pop(context, groupId);
            }
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Back up everything'),
          subtitle: const Text('Save a .hisab file with all your data'),
          onTap: () => shareBackupFile(context),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete all data',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => _confirmClear(context),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'Every group, friend and expense on this phone will be removed. '
          'Make a backup first if you might need them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    appStore.clearAll();
    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  Widget _about(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(height: 12),
              Text(appName, style: theme.textTheme.titleLarge),
              Text(
                'Version $appVersion',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _aboutRow(context, 'Built by', builtBy),
              _aboutRow(context, 'Build date', buildDate),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Made in India 🇮🇳', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
              
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class IndiaFlag extends StatelessWidget {
  const IndiaFlag({super.key, this.width = 30});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 2 / 3;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: outline, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          children: [
            const Expanded(child: ColoredBox(color: Color(0xFFFF9933))),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Container(
                    width: height * 0.26,
                    height: height * 0.26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF000080),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(child: ColoredBox(color: Color(0xFF138808))),
          ],
        ),
      ),
    );
  }
}
