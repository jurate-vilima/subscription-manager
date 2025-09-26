import 'dart:io';

import 'package:hive/hive.dart';
import 'package:subscription_manager/models/app_settings.dart';
import 'package:subscription_manager/models/billing_cycle_adapter.dart';
import 'package:subscription_manager/models/subscription.dart';

class HiveTestContext {
  HiveTestContext({List<int>? encryptionKey})
      : _encryptionKey =
            encryptionKey ?? List<int>.generate(32, (index) => index) {
    _cipher = HiveAesCipher(List<int>.from(_encryptionKey));
  }

  final List<int> _encryptionKey;
  late final HiveAesCipher _cipher;
  late Directory _tempDir;

  Future<void> setUp() async {
    _tempDir = await Directory.systemTemp.createTemp('hive_repo_test');
    Hive.init(_tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SubscriptionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BillingCycleAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    await _openBoxes();
  }

  Future<void> _openBoxes() async {
    await Hive.openBox<Subscription>(
      'subscriptions',
      encryptionCipher: _cipher,
    );
    await Hive.openBox<AppSettings>(
      'settings',
      encryptionCipher: _cipher,
    );
  }

  Future<void> clearBoxes() async {
    await Hive.box<Subscription>('subscriptions').clear();
    await Hive.box<AppSettings>('settings').clear();
  }

  Future<void> reopenBoxes() async {
    await Hive.close();
    Hive.init(_tempDir.path);
    await _openBoxes();
  }

  Future<void> tearDown() async {
    await Hive.close();
    if (await _tempDir.exists()) {
      await _tempDir.delete(recursive: true);
    }
  }
}
