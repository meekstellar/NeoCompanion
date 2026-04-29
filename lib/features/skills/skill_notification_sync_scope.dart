import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'skill_providers.dart';

/// Activates the skill-notification side-effect notifier and refreshes the
/// queue for every known character whenever the app returns to the foreground.
class SkillNotificationSyncScope extends ConsumerStatefulWidget {
  const SkillNotificationSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SkillNotificationSyncScope> createState() =>
      _SkillNotificationSyncScopeState();
}

class _SkillNotificationSyncScopeState
    extends ConsumerState<SkillNotificationSyncScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final tokens =
        ref.read(storedCharactersProvider).value ?? const [];
    for (final t in tokens) {
      ref.invalidate(skillQueueProvider(t.characterId));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(skillNotificationSyncProvider);
    return widget.child;
  }
}
