import '../../features/assets/data/dto/asset_item.dart';
import '../../features/characters/data/dto/character_location.dart';
import '../../features/characters/data/dto/character_portrait.dart';
import '../../features/characters/data/dto/character_public_info.dart';
import '../../features/characters/data/dto/character_ship.dart';
import '../../features/market/data/dto/market_order.dart';
import '../../features/server_status/data/dto/server_status.dart';
import '../../features/skills/data/dto/character_skills.dart';
import '../../features/skills/data/dto/skill_queue_entry.dart';
import '../../features/wallet/data/dto/wallet_journal_entry.dart';
import '../../features/wallet/data/dto/wallet_transaction_entry.dart';
import '../auth/token_set.dart';

/// Fixed plausible data for screenshots. All ids are real EVE type /
/// system / station ids so the SDE can resolve names and the type-icon
/// service serves real artwork.
class DemoData {
  DemoData._();

  // The demo character. ID is in CCP's player range but the persona is
  // fictional. Portraits are served by images.evetech.net for any id, so
  // a non-existent character still gets a procedurally-generated face.
  static const int characterId = 95000001;
  static const String characterName = 'Capsuleer Demo';
  static const int corporationId = 1000035; // Caldari Provisions (NPC)
  // Fictional alliance id — no real-world match, so the alliance logo
  // service 404s and the badge falls through to its empty placeholder.
  // The displayed name plays on the demo angle: the character is in
  // "witness protection", which is why their identity is anonymized.
  static const int allianceId = 99000042;
  static const int factionId = 500001; // Caldari State

  // Jita IV - Moon 4 - Caldari Navy Assembly Plant.
  static const int homeStationId = 60003760;
  static const int homeSystemId = 30000142;
  static const int regionTheForgeId = 10000002;

  // Type ids for plausible items.
  static const int shipTypeId = 17726; // Caldari Navy Hookbill
  static const int largeSkillInjectorTypeId = 40520;
  static const int plexTypeId = 44992;
  static const int tritaniumTypeId = 34;
  static const int pyeriteTypeId = 35;
  static const int mexallonTypeId = 36;
  static const int isogenTypeId = 37;
  static const int helium3TypeId = 16273;
  static const int caldariShipsSkillId = 3338;
  static const int spaceshipCommandSkillId = 3327;
  static const int gunneryHybridTurretSkillId = 3300;
  static const int navigationSkillId = 3449;

  static TokenSet get tokenSet {
    final now = DateTime.now();
    return TokenSet(
      characterId: characterId,
      characterName: characterName,
      // Synthetic but parseable; never sent to ESI in demo mode.
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      // Far-future expiry so isExpired stays false and no refresh is
      // attempted even if a stray code path forgets the demo guard.
      expiresAt: now.add(const Duration(days: 365 * 10)),
      scopes: const ['publicData'],
    );
  }

  static CharacterPublicInfo get publicInfo => CharacterPublicInfo(
        name: characterName,
        corporationId: corporationId,
        allianceId: allianceId,
        factionId: factionId,
        raceId: 1,
        bloodlineId: 2,
        securityStatus: 4.7,
        birthday: DateTime.utc(2014, 5, 22),
      );

  static const portrait = CharacterPortrait(
    px64: 'https://images.evetech.net/characters/$characterId/portrait?size=64',
    px128:
        'https://images.evetech.net/characters/$characterId/portrait?size=128',
    px256:
        'https://images.evetech.net/characters/$characterId/portrait?size=256',
    px512:
        'https://images.evetech.net/characters/$characterId/portrait?size=512',
  );

  static const location = CharacterLocation(
    solarSystemId: homeSystemId,
    stationId: homeStationId,
  );

  static const ship = CharacterShip(
    shipTypeId: shipTypeId,
    shipItemId: 1024000000001,
    shipName: 'Demo Hookbill',
  );

  static const double walletBalance = 8_412_576_330.42;

  static List<SkillQueueEntry> get skillQueue {
    final now = DateTime.now();
    return [
      SkillQueueEntry(
        skillId: caldariShipsSkillId,
        queuePosition: 0,
        finishedLevel: 5,
        levelStartSp: 226_274,
        levelEndSp: 1_280_000,
        trainingStartSp: 800_000,
        startDate: now.subtract(const Duration(hours: 6)),
        finishDate: now.add(const Duration(hours: 18, minutes: 27)),
      ),
      SkillQueueEntry(
        skillId: gunneryHybridTurretSkillId,
        queuePosition: 1,
        finishedLevel: 5,
        levelStartSp: 226_274,
        levelEndSp: 1_280_000,
        startDate: now.add(const Duration(hours: 18, minutes: 27)),
        finishDate: now.add(const Duration(days: 2, hours: 6)),
      ),
      SkillQueueEntry(
        skillId: navigationSkillId,
        queuePosition: 2,
        finishedLevel: 4,
        levelStartSp: 40_000,
        levelEndSp: 226_274,
        startDate: now.add(const Duration(days: 2, hours: 6)),
        finishDate: now.add(const Duration(days: 5, hours: 14)),
      ),
      SkillQueueEntry(
        skillId: spaceshipCommandSkillId,
        queuePosition: 3,
        finishedLevel: 5,
        levelStartSp: 90_510,
        levelEndSp: 512_000,
        startDate: now.add(const Duration(days: 5, hours: 14)),
        finishDate: now.add(const Duration(days: 9, hours: 2)),
      ),
    ];
  }

  static const characterSkills = CharacterSkills(
    totalSp: 78_452_910,
    unallocatedSp: 250_000,
    skills: [
      SkillSummary(
        skillId: caldariShipsSkillId,
        skillpointsInSkill: 800_000,
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
      ),
      SkillSummary(
        skillId: gunneryHybridTurretSkillId,
        skillpointsInSkill: 226_274,
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
      ),
      SkillSummary(
        skillId: navigationSkillId,
        skillpointsInSkill: 40_000,
        trainedSkillLevel: 3,
        activeSkillLevel: 3,
      ),
      SkillSummary(
        skillId: spaceshipCommandSkillId,
        skillpointsInSkill: 256_000,
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
      ),
    ],
  );

  static List<AssetItem> get assets => [
        AssetItem(
          itemId: 1700000000001,
          typeId: shipTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 1,
          isSingleton: true,
          isBlueprintCopy: false,
        ),
        AssetItem(
          itemId: 1700000000002,
          typeId: largeSkillInjectorTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 6,
          isSingleton: false,
          isBlueprintCopy: false,
        ),
        AssetItem(
          itemId: 1700000000003,
          typeId: plexTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 500,
          isSingleton: false,
          isBlueprintCopy: false,
        ),
        AssetItem(
          itemId: 1700000000004,
          typeId: tritaniumTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 12_500_000,
          isSingleton: false,
          isBlueprintCopy: false,
        ),
        AssetItem(
          itemId: 1700000000005,
          typeId: pyeriteTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 4_200_000,
          isSingleton: false,
          isBlueprintCopy: false,
        ),
        AssetItem(
          itemId: 1700000000006,
          typeId: mexallonTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 850_000,
          isSingleton: false,
          isBlueprintCopy: false,
        ),
        AssetItem(
          itemId: 1700000000007,
          typeId: isogenTypeId,
          locationId: homeStationId,
          locationFlag: 'Hangar',
          locationType: 'station',
          quantity: 320_000,
          isSingleton: false,
          isBlueprintCopy: false,
        ),
      ];

  static List<WalletJournalEntry> get walletJournal {
    final now = DateTime.now();
    var balance = walletBalance;
    final entries = <WalletJournalEntry>[];
    var id = 9_000_000_000;
    void add({
      required Duration ago,
      required String refType,
      required double amount,
      String? description,
    }) {
      entries.add(WalletJournalEntry(
        id: id++,
        refType: refType,
        date: now.subtract(ago),
        amount: amount,
        balance: balance,
        description: description,
      ));
      balance -= amount;
    }

    add(
      ago: const Duration(hours: 1, minutes: 12),
      refType: 'market_transaction',
      amount: 184_500_000,
      description: 'Sold 12 × Large Skill Injector',
    );
    add(
      ago: const Duration(hours: 4, minutes: 38),
      refType: 'broker_fee',
      amount: -2_400_000,
      description: 'Broker fee for Jita 4-4',
    );
    add(
      ago: const Duration(hours: 9),
      refType: 'market_transaction',
      amount: -120_000_000,
      description: 'Bought 1 × Caldari Navy Hookbill',
    );
    add(
      ago: const Duration(days: 1, hours: 2),
      refType: 'bounty_prizes',
      amount: 16_750_000,
      description: 'Bounty payout from belt rats',
    );
    add(
      ago: const Duration(days: 1, hours: 22),
      refType: 'corporation_account_withdrawal',
      amount: 50_000_000,
      description: 'Corp dividend',
    );
    add(
      ago: const Duration(days: 2, hours: 6),
      refType: 'mission_reward',
      amount: 8_400_000,
      description: 'L4 mission reward — Worlds Collide',
    );
    add(
      ago: const Duration(days: 2, hours: 8),
      refType: 'mission_reward',
      amount: 11_900_000,
      description: 'L4 mission bonus — Worlds Collide',
    );
    return entries;
  }

  static List<WalletTransactionEntry> get walletTransactions {
    final now = DateTime.now();
    return [
      WalletTransactionEntry(
        transactionId: 81_000_001,
        date: now.subtract(const Duration(hours: 1, minutes: 12)),
        typeId: largeSkillInjectorTypeId,
        quantity: 12,
        unitPrice: 15_375_000,
        isBuy: false,
        isPersonal: true,
        clientId: 90_000_002,
        locationId: homeStationId,
        journalRefId: 9_000_000_000,
      ),
      WalletTransactionEntry(
        transactionId: 81_000_002,
        date: now.subtract(const Duration(hours: 9)),
        typeId: shipTypeId,
        quantity: 1,
        unitPrice: 120_000_000,
        isBuy: true,
        isPersonal: true,
        clientId: 90_000_003,
        locationId: homeStationId,
        journalRefId: 9_000_000_002,
      ),
      WalletTransactionEntry(
        transactionId: 81_000_003,
        date: now.subtract(const Duration(days: 1, hours: 14)),
        typeId: tritaniumTypeId,
        quantity: 5_000_000,
        unitPrice: 5.42,
        isBuy: false,
        isPersonal: true,
        clientId: 90_000_004,
        locationId: homeStationId,
        journalRefId: 9_000_000_004,
      ),
      WalletTransactionEntry(
        transactionId: 81_000_004,
        date: now.subtract(const Duration(days: 2, hours: 1)),
        typeId: helium3TypeId,
        quantity: 50_000,
        unitPrice: 1_250,
        isBuy: false,
        isPersonal: true,
        clientId: 90_000_005,
        locationId: homeStationId,
        journalRefId: 9_000_000_005,
      ),
    ];
  }

  static List<MarketOrder> get marketOrders {
    final now = DateTime.now();
    return [
      MarketOrder(
        orderId: 7_100_000_001,
        typeId: largeSkillInjectorTypeId,
        regionId: regionTheForgeId,
        locationId: homeStationId,
        price: 15_390_000,
        volumeRemain: 28,
        volumeTotal: 40,
        duration: 90,
        issued: now.subtract(const Duration(days: 4, hours: 7)),
        isBuyOrder: false,
        range: 'station',
      ),
      MarketOrder(
        orderId: 7_100_000_002,
        typeId: tritaniumTypeId,
        regionId: regionTheForgeId,
        locationId: homeStationId,
        price: 5.18,
        volumeRemain: 20_000_000,
        volumeTotal: 50_000_000,
        duration: 30,
        issued: now.subtract(const Duration(days: 1, hours: 12)),
        isBuyOrder: true,
        range: 'region',
      ),
      MarketOrder(
        orderId: 7_100_000_003,
        typeId: shipTypeId,
        regionId: regionTheForgeId,
        locationId: homeStationId,
        price: 119_900_000,
        volumeRemain: 3,
        volumeTotal: 5,
        duration: 30,
        issued: now.subtract(const Duration(hours: 14)),
        isBuyOrder: false,
        range: 'station',
      ),
    ];
  }

  static const serverStatus = ServerStatus(
    online: true,
    players: 28_412,
    startTime: null,
    vip: false,
  );

  /// PLEX count summed from `assets` so the chip stays consistent with
  /// what the assets screen displays.
  static int get plexCount => assets
      .where((a) => a.typeId == plexTypeId)
      .fold<int>(0, (s, a) => s + a.quantity);
}
