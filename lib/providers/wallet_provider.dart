import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/db_helper.dart';
import '../../data/models/wallet_model.dart';

class WalletProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  WalletProvider({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper.instance;
  List<WalletModel> _wallets = [];
  bool _isLoading = true;

  List<WalletModel> get wallets => _wallets;
  bool get isLoading => _isLoading;

  double get totalBalance {
    return _wallets.fold(0.0, (sum, wallet) => sum + wallet.currentBalance);
  }

  WalletModel? get defaultWallet {
    if (_wallets.isEmpty) return null;
    return _wallets.firstWhere(
      (w) => w.isDefault,
      orElse: () => _wallets.first,
    );
  }

  Future<void> loadWallets(String defaultCurrencyCode) async {
    _isLoading = true;
    notifyListeners();

    await _dbHelper.seedDefaultWalletsIfEmpty(defaultCurrencyCode);
    _wallets = await _dbHelper.getAllWallets();

    _isLoading = false;
    notifyListeners();
  }

  WalletModel? getById(String id) {
    try {
      return _wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  WalletModel? getWalletById(String? id) {
    if (id == null) return null;
    return getById(id);
  }

  Future<void> addWallet({
    required String nameEn,
    required String nameAr,
    required double initialBalance,
    required String currencyCode,
    required int iconCodePoint,
    String? iconFontFamily,
    required int colorValue,
    required WalletType type,
    bool isDefault = false,
  }) async {
    final willBeDefault = isDefault || _wallets.isEmpty;
    if (willBeDefault && _wallets.isNotEmpty) {
      for (int i = 0; i < _wallets.length; i++) {
        if (_wallets[i].isDefault) {
          final updated = _wallets[i].copyWith(isDefault: false);
          await _dbHelper.updateWallet(updated);
          _wallets[i] = updated;
        }
      }
    }

    final newWallet = WalletModel(
      id: const Uuid().v4(),
      nameEn: nameEn,
      nameAr: nameAr,
      initialBalance: initialBalance,
      currentBalance: initialBalance,
      currencyCode: currencyCode,
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily,
      colorValue: colorValue,
      type: type,
      isDefault: willBeDefault,
    );

    await _dbHelper.insertWallet(newWallet);
    _wallets.add(newWallet);
    notifyListeners();
  }

  Future<void> setDefaultWallet(String id) async {
    final updatedList = <WalletModel>[];
    for (final w in _wallets) {
      final isDef = w.id == id;
      if (w.isDefault != isDef) {
        final updated = w.copyWith(isDefault: isDef);
        await _dbHelper.updateWallet(updated);
        updatedList.add(updated);
      } else {
        updatedList.add(w);
      }
    }
    _wallets = updatedList;
    notifyListeners();
  }

  Future<void> updateWallet(WalletModel wallet) async {
    if (wallet.isDefault) {
      for (int i = 0; i < _wallets.length; i++) {
        if (_wallets[i].id != wallet.id && _wallets[i].isDefault) {
          final unset = _wallets[i].copyWith(isDefault: false);
          await _dbHelper.updateWallet(unset);
          _wallets[i] = unset;
        }
      }
    }
    await _dbHelper.updateWallet(wallet);
    final index = _wallets.indexWhere((w) => w.id == wallet.id);
    if (index != -1) {
      _wallets[index] = wallet;
      notifyListeners();
    }
  }

  Future<void> adjustWalletBalance(String walletId, double delta) async {
    final wallet = getById(walletId);
    if (wallet != null) {
      final updated = wallet.copyWith(
        currentBalance: wallet.currentBalance + delta,
      );
      await updateWallet(updated);
    }
  }

  /// Relabels empty wallets when the app's primary currency changes.
  /// Callers must prevent this operation once financial amounts exist.
  Future<void> updateCurrencyForEmptyWallets(String currencyCode) async {
    final updatedWallets = <WalletModel>[];
    for (final wallet in _wallets) {
      final updated = wallet.copyWith(currencyCode: currencyCode);
      await _dbHelper.updateWallet(updated);
      updatedWallets.add(updated);
    }
    _wallets = updatedWallets;
    notifyListeners();
  }

  Future<void> deleteWallet(String id) async {
    await _dbHelper.deleteWallet(id);
    _wallets.removeWhere((w) => w.id == id);
    notifyListeners();
  }
}
