import 'package:flutter/material.dart';

import 'media.dart';
import 'models.dart';
import 'person_screen.dart';
import 'store.dart';
import 'upi_qr_screen.dart';
import 'widgets.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String _query = '';

  Future<void> _addFriend() async {
    final details = await showPersonDialog(context, title: 'Add friend');
    if (details == null) return;
    final photo = await commitPhoto(details.photo, null, 'people');
    appStore.addPerson(
      name: details.name,
      phone: details.phone,
      upi: details.upi,
      isFriend: true,
      photoPath: photo,
    );
  }

  void _removeFriend(Person person) {
    appStore.setFriend(person, false);
    showMessage(
      context,
      '${person.name} removed from friends',
      SnackBarAction(
        label: 'Undo',
        onPressed: () => appStore.setFriend(person, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final all = appStore.friends;
        final friends = all
            .where((p) => matchesQuery(_query, [p.name, p.phone, p.upi]))
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text('Friends (${all.length})')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addFriend,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add friend'),
          ),
          body: all.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No friends yet',
                  message:
                      'Save people once and add them to any group in a tap.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: SearchField(
                        hint: 'Search by name, phone or UPI',
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Expanded(
                      child: friends.isEmpty
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              message: 'Nobody matches "$_query".',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: friends.length,
                              itemBuilder: (context, i) =>
                                  _tile(context, friends[i]),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Person person) {
    final details = [
      if (person.phone.isNotEmpty) person.phone,
      if (person.upi.isNotEmpty) person.upi,
    ].join(' • ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: NameAvatar(name: person.name, photoPath: person.photoPath),
      title: Text(person.name),
      subtitle: Text(details.isEmpty ? 'No phone or UPI ID' : details),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (person.upi.isNotEmpty)
            IconButton(
              tooltip: 'Show UPI QR',
              icon: const Icon(Icons.qr_code_2_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UpiQrScreen(name: person.name, upi: person.upi),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Remove friend',
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: () => _removeFriend(person),
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PersonScreen(personId: person.id)),
      ),
    );
  }
}
