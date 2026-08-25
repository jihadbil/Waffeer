import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/db_helper.dart';
import '../../data/models/wallet_model.dart';

class WalletProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
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

  Future<void> addWallet({
    required String nameEn,
    required String nameAr,
    required double initialBalance,
    required String currencyCode,
    required int iconCodePoint,
    String? iconFontFamily,
    required int colorValue,
    required WalletType type,
  }) async {
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
      isDefault: _wallets.isEmpty,
    );

    await _dbHelper.insertWallet(newWallet);
    _wallets.add(newWallet);
    notifyListeners();
  }

  Future<void> updateWallet(WalletModel wallet) async {
    await _dbHelper.updateWallet(wallet);
    final index = _wallets.indexWhere((w) => w.id == wallet.id);
    if (index != -1) {
      _wallets[index] = wallet;
      notifyListeners();
    }
  }

  Future<void> deleteWallet(String id) async {
    await _dbHelper.deleteWallet(id);
    _wallets.removeWhere((w) => w.id == id);
    notifyListeners();
  }
}
