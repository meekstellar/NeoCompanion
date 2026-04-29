import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/token_set.dart';
import '../../../core/notifications/notification_providers.dart';
import 'character_sheet_screen.dart';

class CharacterListScreen extends ConsumerWidget {
  const CharacterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(storedCharactersProvider);
    final activeId = ref.watch(activeCharacterIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Characters')),
      body: characters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = list[i];
              return _CharacterTile(
                token: t,
                isActive: t.characterId == activeId,
                onSelect: () {
                  ref
                      .read(activeCharacterIdProvider.notifier)
                      .set(t.characterId);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CharacterSheetScreen(characterId: t.characterId),
                    ),
                  );
                },
                onSignOut: () async {
                  final tm = ref.read(tokenManagerProvider);
                  await tm.remove(t.characterId);
                  if (activeId == t.characterId) {
                    ref.read(activeCharacterIdProvider.notifier).set(null);
                  }
                  ref.invalidate(storedCharactersProvider);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCharacter(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add character'),
      ),
    );
  }

  Future<void> _addCharacter(BuildContext context, WidgetRef ref) async {
    final sso = ref.read(eveSsoServiceProvider);
    final wasEmpty = (ref.read(storedCharactersProvider).value ?? const [])
        .isEmpty;
    try {
      final character = await sso.signIn();
      ref.read(activeCharacterIdProvider.notifier).set(character.id);
      ref.invalidate(storedCharactersProvider);
      if (wasEmpty) {
        // First character — ask for notification permission so skill-completion
        // reminders can fire. iOS only prompts the user once.
        unawaited(ref.read(notificationServiceProvider).requestPermissions());
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No characters yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a character to start tracking skills and wallet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.token,
    required this.isActive,
    required this.onSelect,
    required this.onSignOut,
  });

  final TokenSet token;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onSelect,
      leading: CircleAvatar(child: Text(token.characterName.characters.first)),
      title: Text(token.characterName),
      subtitle: Text('ID ${token.characterId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle, size: 18),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}
