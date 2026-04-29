import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Persistent local cache of EVE inventory type ids → names plus a
/// freshness fingerprint (`firstPageEtag`, `pageCount`) so the app can
/// ask CCP whether anything has changed without re-fetching the whole
/// list.
class TypesDatabase extends ChangeNotifier {
  TypesDatabase(this._file);

  final File _file;
  Map<int, String> _names = const {};
  DateTime? _lastUpdatedAt;
  String? _firstPageEtag;
  int? _pageCount;

  String? lookup(int typeId) => _names[typeId];

  bool get isReady => _names.isNotEmpty;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  int get count => _names.length;
  String? get firstPageEtag => _firstPageEtag;
  int? get pageCount => _pageCount;

  Future<void> load() async {
    if (!await _file.exists()) return;
    try {
      final raw = await _file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _lastUpdatedAt = DateTime.parse(data['lastUpdatedAt'] as String);
      _firstPageEtag = data['firstPageEtag'] as String?;
      _pageCount = (data['pageCount'] as num?)?.toInt();
      final names = data['names'] as Map<String, dynamic>;
      _names = {
        for (final e in names.entries) int.parse(e.key): e.value as String,
      };
    } catch (_) {
      // Corrupt file — keep empty state. Next update overwrites.
    }
  }

  Future<void> commit({
    required Map<int, String> names,
    required String? firstPageEtag,
    required int? pageCount,
  }) async {
    _names = Map.unmodifiable(names);
    _lastUpdatedAt = DateTime.now();
    _firstPageEtag = firstPageEtag;
    _pageCount = pageCount;
    final json = {
      'lastUpdatedAt': _lastUpdatedAt!.toIso8601String(),
      'firstPageEtag': _firstPageEtag,
      'pageCount': _pageCount,
      'names': {for (final e in _names.entries) e.key.toString(): e.value},
    };
    await _file.writeAsString(jsonEncode(json));
    notifyListeners();
  }
}
