import '../../features/assets/asset_node.dart';
import '../../features/assets/asset_providers.dart';
import '../../features/characters/character_providers.dart';
import '../../features/market/market_providers.dart';
import '../../features/server_status/server_status_providers.dart';
import '../../features/skills/skill_providers.dart';
import '../../features/wallet/wallet_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/token_set.dart';
import 'demo_data.dart';

/// Riverpod overrides that swap every ESI-backed provider for a static
/// fixture. Apply once at startup via `ProviderScope(overrides: [...])`
/// when [kDemoMode] is true.
///
/// Coverage: every screen referenced from the character sheet (sheet
/// itself, skills, wallet journal/transactions, market orders, assets,
/// server status). Other features (industry, planets, contracts, mail,
/// loyalty, fittings) still try to hit ESI; expand this list when new
/// screens need to appear in screenshots.
// Return type is inferred. Riverpod 3 keeps `Override` as a sealed,
// non-exported type, so spelling it explicitly here doesn't compile —
// inference picks it up just fine from the literal contents.
// ignore: strict_top_level_inference
demoOverrides() {
  return [
    storedCharactersProvider
        .overrideWith((ref) async => <TokenSet>[DemoData.tokenSet]),
    serverStatusProvider.overrideWith((ref) async => DemoData.serverStatus),
    characterSheetProvider.overrideWith((ref, characterId) async {
      final info = DemoData.publicInfo;
      return CharacterSheetData(
        publicInfo: info,
        portrait: DemoData.portrait,
        location: DemoData.location,
        ship: DemoData.ship,
        walletBalance: DemoData.walletBalance,
        resolvedNames: const {
          DemoData.homeStationId: 'Jita IV - Moon 4 - '
              'Caldari Navy Assembly Plant',
          DemoData.homeSystemId: 'Jita',
          DemoData.corporationId: 'Caldari Provisions',
          DemoData.allianceId: 'CONCORD Witness Protection',
          DemoData.factionId: 'Caldari State',
          DemoData.shipTypeId: 'Caldari Navy Hookbill',
        },
      );
    }),
    skillQueueProvider.overrideWith((ref, characterId) async {
      return SkillQueueData(
        queue: DemoData.skillQueue,
        skills: DemoData.characterSkills,
        skillNames: const {
          DemoData.caldariShipsSkillId: 'Caldari Frigate',
          DemoData.gunneryHybridTurretSkillId: 'Small Hybrid Turret',
          DemoData.navigationSkillId: 'Navigation',
          DemoData.spaceshipCommandSkillId: 'Spaceship Command',
        },
      );
    }),
    allSkillsProvider.overrideWith((ref, characterId) async {
      return AllSkillsData(
        skills: DemoData.characterSkills,
        names: const {
          DemoData.caldariShipsSkillId: 'Caldari Frigate',
          DemoData.gunneryHybridTurretSkillId: 'Small Hybrid Turret',
          DemoData.navigationSkillId: 'Navigation',
          DemoData.spaceshipCommandSkillId: 'Spaceship Command',
        },
      );
    }),
    cloneStateProvider
        .overrideWith((ref, characterId) async => CloneState.omega),
    walletJournalProvider
        .overrideWith((ref, characterId) async => DemoData.walletJournal),
    walletTransactionsProvider
        .overrideWith((ref, characterId) async => DemoData.walletTransactions),
    marketOrdersProvider.overrideWith((ref, characterId) async {
      const typeNames = {
        DemoData.largeSkillInjectorTypeId: 'Large Skill Injector',
        DemoData.tritaniumTypeId: 'Tritanium',
        DemoData.shipTypeId: 'Caldari Navy Hookbill',
      };
      const locationNames = {
        DemoData.homeStationId:
            'Jita IV - Moon 4 - Caldari Navy Assembly Plant',
      };
      return MarketOrdersData(
        orders: DemoData.marketOrders,
        typeNames: typeNames,
        locationNames: locationNames,
      );
    }),
    marketLatestPriceProvider
        .overrideWith((ref, typeId) async => _demoPrice(typeId)),
    assetsProvider.overrideWith((ref, characterId) async {
      final items = DemoData.assets;
      return AssetsData(
        items: items,
        tree: buildAssetTree(items),
        typeNames: const {
          DemoData.shipTypeId: 'Caldari Navy Hookbill',
          DemoData.largeSkillInjectorTypeId: 'Large Skill Injector',
          DemoData.plexTypeId: 'PLEX',
          DemoData.tritaniumTypeId: 'Tritanium',
          DemoData.pyeriteTypeId: 'Pyerite',
          DemoData.mexallonTypeId: 'Mexallon',
          DemoData.isogenTypeId: 'Isogen',
        },
        customNames: const {},
        itemIdToType: {for (final i in items) i.itemId: i.typeId},
        locationNames: const {
          DemoData.homeStationId: 'Jita IV - Moon 4 - '
              'Caldari Navy Assembly Plant',
        },
      );
    }),
    characterPlexCountProvider
        .overrideWith((ref, characterId) async => DemoData.plexCount),
  ];
}

double? _demoPrice(int typeId) {
  switch (typeId) {
    case DemoData.plexTypeId:
      return 4_750_000;
    case DemoData.largeSkillInjectorTypeId:
      return 750_000_000;
    case DemoData.tritaniumTypeId:
      return 5.42;
    default:
      return null;
  }
}
