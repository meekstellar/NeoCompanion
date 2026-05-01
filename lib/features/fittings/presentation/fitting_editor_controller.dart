import 'package:flutter/foundation.dart';

import '../data/dto/fitting.dart';

/// Mutable state shared between the editor body and its host screen.
/// Holds the working copy of [items] plus a name cache, exposes a
/// `isDirty` flag against the initial snapshot, and notifies listeners
/// on every mutation so the host can persist (local fits) or render a
/// dirty marker (ESI fits).
class FittingEditorController extends ChangeNotifier {
  FittingEditorController({
    required List<FittingItem> initialItems,
    required Map<int, String> initialTypeNames,
  })  : _initialItems = List.unmodifiable(initialItems),
        _items = List.of(initialItems),
        _typeNames = Map.of(initialTypeNames);

  final List<FittingItem> _initialItems;
  List<FittingItem> _items;
  final Map<int, String> _typeNames;

  List<FittingItem> get items => _items;
  Map<int, String> get typeNames => _typeNames;

  bool get isDirty {
    if (_items.length != _initialItems.length) return true;
    for (var i = 0; i < _items.length; i++) {
      final a = _items[i];
      final b = _initialItems[i];
      if (a.flag != b.flag || a.typeId != b.typeId || a.quantity != b.quantity) {
        return true;
      }
    }
    return false;
  }

  String resolveName(int typeId) => _typeNames[typeId] ?? '#$typeId';

  /// Replaces (or installs) the module at [flag] with [typeId]. Quantity
  /// of an existing item is preserved; new entries get quantity 1.
  void replaceModule(String flag, int typeId, {String? typeName}) {
    if (typeName != null) _typeNames[typeId] = typeName;
    final idx = _items.indexWhere((it) => it.flag == flag);
    if (idx == -1) {
      _items = [..._items, FittingItem(flag: flag, quantity: 1, typeId: typeId)];
    } else {
      final old = _items[idx];
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (i == idx)
            FittingItem(flag: flag, quantity: old.quantity, typeId: typeId)
          else
            _items[i],
      ];
    }
    notifyListeners();
  }

  void removeModule(String flag) {
    final next = _items.where((it) => it.flag != flag).toList();
    if (next.length == _items.length) return;
    _items = next;
    notifyListeners();
  }

  /// Adds [quantity] of [typeId] to a stackable bucket like drone bay
  /// or cargo. Items in the same bucket are keyed by `(flag, typeId)`,
  /// so adding the same drone twice just bumps the quantity instead of
  /// growing the list.
  void addStackable(
    String flag,
    int typeId, {
    String? typeName,
    int quantity = 1,
  }) {
    if (quantity <= 0) return;
    if (typeName != null) _typeNames[typeId] = typeName;
    final idx =
        _items.indexWhere((it) => it.flag == flag && it.typeId == typeId);
    if (idx == -1) {
      _items = [
        ..._items,
        FittingItem(flag: flag, quantity: quantity, typeId: typeId),
      ];
    } else {
      final old = _items[idx];
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (i == idx)
            FittingItem(
              flag: flag,
              quantity: old.quantity + quantity,
              typeId: typeId,
            )
          else
            _items[i],
      ];
    }
    notifyListeners();
  }

  void removeStack(String flag, int typeId) {
    final next = _items
        .where((it) => !(it.flag == flag && it.typeId == typeId))
        .toList();
    if (next.length == _items.length) return;
    _items = next;
    notifyListeners();
  }

  void setStackQuantity(String flag, int typeId, int quantity) {
    if (quantity <= 0) {
      removeStack(flag, typeId);
      return;
    }
    final idx =
        _items.indexWhere((it) => it.flag == flag && it.typeId == typeId);
    if (idx == -1) return;
    _items = [
      for (var i = 0; i < _items.length; i++)
        if (i == idx)
          FittingItem(flag: flag, quantity: quantity, typeId: typeId)
        else
          _items[i],
    ];
    notifyListeners();
  }

  void resetToInitial() {
    _items = List.of(_initialItems);
    notifyListeners();
  }
}
