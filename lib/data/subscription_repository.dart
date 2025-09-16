import 'package:hive/hive.dart';
import 'package:subscription_manager/models/subscription.dart';

class SubscriptionRepository {
  final Box<Subscription> _box = Hive.box<Subscription>('subscriptions');

  List<Subscription> getAll() => _box.values.toList();

  Future<void> add(Subscription s) async => _box.put(s.id, s);

  Future<void> update(Subscription s) async => _box.put(s.id, s);

  Future<void> remove(String id) async => _box.delete(id);
}
