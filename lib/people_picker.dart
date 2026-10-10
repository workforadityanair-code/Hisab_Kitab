import 'package:flutter/material.dart';

import 'media.dart';
import 'store.dart';
import 'widgets.dart';

Future<Set<String>?> pickPeople(
  BuildContext context, {
  required String title,
  required Set<String> initial,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PeoplePicker(title: title, initial: initial),
  );
}

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.title, required this.initial});

  final String title;
  final Set<String> initial;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  Future<void> _newPerson() async {
    final details = await showPersonDialog(context, title: 'New person');
    if (details == null) return;
    final photo = await commitPhoto(details.photo, null, 'people');
    final person = appStore.addPerson(
      name: details.name,
      phone: details.phone,
      upi: details.upi,
      photoPath: photo,
    );
    setState(() => _selected.add(person.id));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final candidates = appStore.selectablePeople
            .where((p) => matchesQuery(_query, [p.name, p.phone, p.upi]))
            .toList();
        return SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _newPerson,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('New person'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchField(
                  hint: 'Search people',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: candidates.isEmpty
                    ? EmptyState(
                        icon: Icons.person_outline_rounded,
                        title: _query.isEmpty ? 'No people yet' : 'No matches',
                        message: _query.isEmpty
                            ? 'Add a new person to get started.'
                            : 'Nobody matches "$_query".',
                      )
                    : ListView(
                        children: [
                          for (final p in candidates)
                            CheckboxListTile(
                              value: _selected.contains(p.id),
                              secondary: NameAvatar(
                                name: p.name,
                                photoPath: p.photoPath,
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                p.isFriend
                                    ? (p.phone.isEmpty ? 'Friend' : p.phone)
                                    : 'Not in friends',
                              ),
                              onChanged: (on) => setState(() {
                                if (on == true) {
                                  _selected.add(p.id);
                                } else {
                                  _selected.remove(p.id);
                                }
                              }),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop<Set<String>>(context, _selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text('Done (${_selected.length})'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
