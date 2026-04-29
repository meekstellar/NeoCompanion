import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/characters/data/dto/character_location.dart';
import 'package:neocompanion/features/characters/data/dto/character_portrait.dart';
import 'package:neocompanion/features/characters/data/dto/character_public_info.dart';
import 'package:neocompanion/features/characters/data/dto/character_ship.dart';
import 'package:neocompanion/features/characters/data/dto/universe_name.dart';

void main() {
  group('CharacterPublicInfo', () {
    test('parses required and optional fields', () {
      final dto = CharacterPublicInfo.fromJson({
        'name': 'Meek Stellar',
        'corporation_id': 109299958,
        'alliance_id': 434243723,
        'birthday': '2015-03-24T11:37:00Z',
        'security_status': 5.5,
        'title': 'Capsuleer',
      });
      expect(dto.name, 'Meek Stellar');
      expect(dto.corporationId, 109299958);
      expect(dto.allianceId, 434243723);
      expect(dto.securityStatus, 5.5);
      expect(dto.title, 'Capsuleer');
      expect(dto.birthday.year, 2015);
    });

    test('treats missing security_status as 0', () {
      final dto = CharacterPublicInfo.fromJson({
        'name': 'Newbie',
        'corporation_id': 1,
        'birthday': '2024-01-01T00:00:00Z',
      });
      expect(dto.securityStatus, 0.0);
      expect(dto.allianceId, isNull);
    });
  });

  test('CharacterPortrait parses all four sizes', () {
    final dto = CharacterPortrait.fromJson({
      'px64x64': 'a',
      'px128x128': 'b',
      'px256x256': 'c',
      'px512x512': 'd',
    });
    expect([dto.px64, dto.px128, dto.px256, dto.px512], ['a', 'b', 'c', 'd']);
  });

  group('CharacterLocation', () {
    test('parses with station only', () {
      final dto = CharacterLocation.fromJson({
        'solar_system_id': 30002505,
        'station_id': 60004756,
      });
      expect(dto.solarSystemId, 30002505);
      expect(dto.stationId, 60004756);
      expect(dto.structureId, isNull);
    });

    test('parses 64-bit structure_id (returned as num)', () {
      final dto = CharacterLocation.fromJson({
        'solar_system_id': 30002505,
        'structure_id': 1000000016989,
      });
      expect(dto.structureId, 1000000016989);
    });
  });

  test('CharacterShip parses 64-bit ship_item_id', () {
    final dto = CharacterShip.fromJson({
      'ship_type_id': 670,
      'ship_item_id': 1000000016991,
      'ship_name': 'SCPT Nireus',
    });
    expect(dto.shipTypeId, 670);
    expect(dto.shipItemId, 1000000016991);
    expect(dto.shipName, 'SCPT Nireus');
  });

  group('UniverseName', () {
    test('parses known categories', () {
      final dto = UniverseName.fromJson({
        'id': 30002505,
        'name': 'Jita',
        'category': 'solar_system',
      });
      expect(dto.id, 30002505);
      expect(dto.name, 'Jita');
      expect(dto.category, UniverseNameCategory.solarSystem);
    });

    test('falls back to unknown for unfamiliar categories', () {
      final dto = UniverseName.fromJson({
        'id': 1,
        'name': 'X',
        'category': 'something_new',
      });
      expect(dto.category, UniverseNameCategory.unknown);
    });
  });
}
