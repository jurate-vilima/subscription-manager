import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/utils/formatters.dart';
import 'package:subscription_manager/utils/calc.dart';
import 'package:subscription_manager/utils/url_helpers.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';
import 'package:subscription_manager/models/billing_cycle.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SubscriptionListViewModel>();
    final settings = context.watch<SettingsViewModel>().state;
    final l = AppLocalizations.of(context)!;

    final m = totalMonthly(vm.items);
    final y = totalYearly(vm.items);
    final mixed = vm.items.any((s) => s.currency != settings.defaultCurrency);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.monthlyTotal(
                          Formatters.money(m, settings.defaultCurrency),
                        ),
                      ),
                      Text(
                        l.yearlyTotal(
                          Formatters.money(y, settings.defaultCurrency),
                        ),
                      ),
                    ],
                  ),
                  if (mixed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.currenciesDiffer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: vm.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.noSubscriptionsYet),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/add'),
                          icon: const Icon(Icons.add),
                          label: Text(l.addFirstSubscription),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: vm.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = vm.items[i];
                      final money = Formatters.money(s.cost, s.currency);
                      final next = Formatters.dateShort(s.nextRenewalDate);

                      final cycleText = _cycleText(context, s.billingCycle);
                      return ListTile(
                        key: ValueKey(s.id),
                        title: Text(s.serviceName),
                        subtitle: Text(
                          '$money • $cycleText • ${l.nextLabel(next)}',
                        ),
                        onTap: () => context.push('/edit/${s.id}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (s.cancellationUrl != null &&
                                s.cancellationUrl!.trim().isNotEmpty)
                              IconButton(
                                tooltip: l.manageCancelTooltip,
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () =>
                                    UrlHelpers.open(context, s.cancellationUrl),
                              ),
                            IconButton(
                              tooltip: l.deleteSubscriptionTooltip,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await vm.removeWithMemory(s.id);
                                if (context.mounted) {
                                  final sb = ScaffoldMessenger.of(context);
                                  sb.clearSnackBars();
                                  sb.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l.deletedSubscription(s.serviceName),
                                      ),
                                      action: SnackBarAction(
                                        label: l.undo,
                                        onPressed: () => vm.undoLastDelete(l),
                                      ),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        label: Text(l.add),
        icon: const Icon(Icons.add),
      ),
    );
  }

  String _cycleText(BuildContext context, BillingCycle cycle) {
    final l = AppLocalizations.of(context)!;
    switch (cycle) {
      case BillingCycle.daily:
        return l.cycleDaily;
      case BillingCycle.weekly:
        return l.cycleWeekly;
      case BillingCycle.monthly:
        return l.cycleMonthly;
      case BillingCycle.yearly:
        return l.cycleYearly;
      case BillingCycle.custom:
        return l.cycleCustom;
    }
  }
}
