import 'package:flutter/material.dart';

import 'media.dart';
import 'people_picker.dart';
import 'store.dart';
import 'widgets.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  Set<String> _memberIds = {};
  String? _photo;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickPeople(
      context,
      title: 'Add people',
      initial: _memberIds,
    );
    if (picked == null) return;
    setState(() => _memberIds = picked);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Give the group a name');
      return;
    }
    final photo = await commitPhoto(_photo, null, 'groups');
    final group = appStore.createGroup(name, _memberIds, photoPath: photo);
    if (mounted) Navigator.pop(context, group);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = _memberIds.toList()
      ..sort((a, b) => appStore.nameOf(a).compareTo(appStore.nameOf(b)));

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: PhotoPicker(
                label: _name.text.isEmpty ? 'Group' : _name.text,
                photoPath: _photo,
                radius: 44,
                icon: Icons.add_a_photo_rounded,
                onChanged: (v) => setState(() => _photo = v),
              ),
            ),
          ),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'Goa trip, Flat 4B, Office lunch',
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text('People', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add people'),
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: NameAvatar(
              name: appStore.meName,
              photoPath: appStore.hasProfile ? appStore.me.photoPath : null,
            ),
            title: Text('${appStore.meName} (you)'),
          ),
          for (final id in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: NameAvatar(
                name: appStore.nameOf(id),
                photoPath: appStore.personById(id)?.photoPath,
              ),
              title: Text(appStore.nameOf(id)),
            ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Create group'),
          ),
        ],
      ),
    );
  }
}
