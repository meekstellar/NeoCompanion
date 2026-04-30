import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/scope_compatibility.dart';
import '../../../core/auth/sso_scopes.dart';
import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/item_database_screen.dart';
import '../../assets/asset_providers.dart';
import '../../assets/presentation/assets_screen.dart';
import '../../clones/presentation/jump_clones_screen.dart';
import '../../fittings/presentation/fittings_screen.dart';
import '../../mail/presentation/mail_screen.dart';
import '../../market/presentation/market_orders_screen.dart';
import '../../skills/presentation/skill_queue_screen.dart';
import '../../wallet/presentation/wallet_journal_screen.dart';
import '../character_providers.dart';
import 'character_details_screen.dart';

class CharacterSheetScreen extends ConsumerWidget {
  const CharacterSheetScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(characterSheetProvider(characterId));
    // Background prefetch of the slow per-character endpoints so the
    // dedicated screens open instantly. ref.listen subscribes for this
    // screen's lifetime, which keeps the providers' cached values
    // around even between visits.
    ref.listen(assetsProvider(characterId), (_, _) {});
    return Scaffold(
      appBar: AppBar(
        title: sheet.maybeWhen(
          data: (d) => Text(d.publicInfo.name),
          orElse: () => const Text('Character'),
        ),
        actions: [
          TextButton(
            onPressed: () => _logout(context, ref),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: sheet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () => ref.invalidate(characterSheetProvider(characterId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(characterSheetProvider(characterId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            children: [
              _ScopeUpgradeBanner(characterId: characterId),
              _HeaderCard(data: data),
              const SizedBox(height: 24),
              const _SectionHeader('Character'),
              _MenuCard(
                rows: [
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/Biography.png',
                    title: 'Character Sheet',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CharacterDetailsScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/SkillQueue.png',
                    title: 'Skill Queue',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SkillQueueScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/Mail.png',
                    title: 'Mail',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MailScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/JumpClones.png',
                    title: 'Jump Clones',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            JumpClonesScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/Wallet.png',
                    title: 'Wealth',
                    subtitle: '${_formatIsk(data.walletBalance)} ISK',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            WalletJournalScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/Assets.png',
                    title: 'Assets',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AssetsScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/Fitting.png',
                    title: 'Fittings',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FittingsScreen(characterId: characterId),
                      ),
                    ),
                  ),
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/MarketOrders.png',
                    title: 'Market Orders',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MarketOrdersScreen(characterId: characterId),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionHeader('Database'),
              _MenuCard(
                rows: [
                  _MenuRow(
                    iconAsset: 'assets/icons/menu/Inventory.png',
                    title: 'Item Database',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ItemDatabaseScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final tm = ref.read(tokenManagerProvider);
    await tm.remove(characterId);
    if (ref.read(activeCharacterIdProvider) == characterId) {
      ref.read(activeCharacterIdProvider.notifier).set(null);
    }
    ref.invalidate(storedCharactersProvider);
    navigator.pop();
  }
}

String _formatIsk(double balance) {
  return NumberFormat('#,##0.00', 'en_US').format(balance);
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});
  final CharacterSheetData data;

  @override
  Widget build(BuildContext context) {
    final corpName = data.nameOf(data.publicInfo.corporationId) ??
        'Corp #${data.publicInfo.corporationId}';
    final allianceName = data.publicInfo.allianceId == null
        ? null
        : data.nameOf(data.publicInfo.allianceId) ??
            'Alliance #${data.publicInfo.allianceId}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: data.portrait.px128,
                width: 64,
                height: 64,
                placeholder: (_, _) => const SizedBox(width: 64, height: 64),
                errorWidget: (_, _, _) => const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.person, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LogoLine(
                    imageUrl:
                        'https://images.evetech.net/corporations/${data.publicInfo.corporationId}/logo?size=32',
                    label: corpName,
                  ),
                  if (allianceName != null) ...[
                    const SizedBox(height: 6),
                    _LogoLine(
                      imageUrl:
                          'https://images.evetech.net/alliances/${data.publicInfo.allianceId}/logo?size=32',
                      label: allianceName,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoLine extends StatelessWidget {
  const _LogoLine({required this.imageUrl, required this.label});
  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          width: 18,
          height: 18,
          placeholder: (_, _) => const SizedBox(width: 18, height: 18),
          errorWidget: (_, _, _) => const SizedBox(width: 18, height: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: Theme.of(context).hintColor,
            ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.rows});
  final List<_MenuRow> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(const Divider(height: 1, indent: 56));
      }
      children.add(rows[i]);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.onTap,
    this.iconAsset,
    this.icon,
    this.subtitle,
  }) : assert(iconAsset != null || icon != null,
            'Provide either iconAsset or icon');

  final String? iconAsset;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).iconTheme.color;
    return ListTile(
      onTap: onTap,
      leading: iconAsset != null
          ? Image.asset(iconAsset!, width: 28, height: 28, color: color)
          : Icon(icon, size: 26, color: color),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(describeEsiError(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ScopeUpgradeBanner extends ConsumerWidget {
  const _ScopeUpgradeBanner({required this.characterId});
  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(storedCharactersProvider).value ?? const [];
    final token = tokens.where((t) => t.characterId == characterId).firstOrNull;
    if (token == null) return const SizedBox.shrink();

    final missing = missingScopes(
      have: token.scopes,
      required: eveMvpScopes,
    );
    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Re-authorize to enable new features',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${missing.length} new scope${missing.length == 1 ? '' : 's'} '
            'needed since you last signed in.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () => _reauthorize(context, ref),
              child: const Text('Re-authorize'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reauthorize(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(eveSsoServiceProvider).signIn();
      ref.invalidate(storedCharactersProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeEsiError(e))),
      );
    }
  }
}
