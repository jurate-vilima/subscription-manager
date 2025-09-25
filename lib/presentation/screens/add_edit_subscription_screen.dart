import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';

import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/models/billing_cycle.dart';
import 'package:subscription_manager/models/subscription.dart';
import 'package:subscription_manager/services/cancellation_links_service.dart';

class AddEditSubscriptionScreen extends StatefulWidget {
  final String? editId;

  const AddEditSubscriptionScreen({super.key, this.editId});

  @override
  State<AddEditSubscriptionScreen> createState() =>
      _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends State<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _serviceNameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  late final TextEditingController _currencyCtrl;
  final _categoryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController();

  BillingCycle _cycle = BillingCycle.monthly;
  DateTime? _nextRenewal;

  Subscription? _editing;
  bool _saving = false;

  Subscription? _findById(List<Subscription> items, String id) {
    for (final s in items) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    final settings = context.read<SettingsViewModel>().state;
    _currencyCtrl = TextEditingController(text: settings.defaultCurrency);

    if (widget.editId != null) {
      final vm = context.read<SubscriptionListViewModel>();
      _editing = _findById(vm.items, widget.editId!);

      if (_editing != null) {
        _serviceNameCtrl.text = _editing!.serviceName;
        _costCtrl.text = _editing!.cost.toString();
        _currencyCtrl.text = _editing!.currency;
        _cycle = _editing!.billingCycle;
        _nextRenewal = _editing!.nextRenewalDate;
        _categoryCtrl.text = _editing!.category ?? '';
        _notesCtrl.text = _editing!.notes ?? '';
        _urlCtrl.text = _editing!.cancellationUrl ?? '';
        _intervalCtrl.text = _editing!.customCycleDays?.toString() ?? '';
      }
    }

    _serviceNameCtrl.addListener(_suggestCancellationUrl);
  }

  @override
  void dispose() {
    _serviceNameCtrl.removeListener(_suggestCancellationUrl);
    _serviceNameCtrl.dispose();
    _costCtrl.dispose();
    _currencyCtrl.dispose();
    _categoryCtrl.dispose();
    _notesCtrl.dispose();
    _urlCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _suggestCancellationUrl() {
    final link = CancellationLinksService().getLink(
      _serviceNameCtrl.text.trim(),
    );
    if (link != null && _urlCtrl.text.trim().isEmpty) {
      _urlCtrl.text = link;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _nextRenewal ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextRenewal = picked);
  }

  String? _validateUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final uri = Uri.tryParse(v.trim());
    if (uri != null &&
        uri.isAbsolute &&
        uri.scheme.isNotEmpty &&
        uri.host.isNotEmpty) {
      return null;
    }
    final l = AppLocalizations.of(context)!;
    return l.invalidUrl;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<SubscriptionListViewModel>();
    final dateFmt = DateFormat.yMMMd();
    final isEdit = _editing != null;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l.editSubscription : l.addSubscription),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const ValueKey('serviceNameField'),
                controller: _serviceNameCtrl,
                decoration: InputDecoration(
                  labelText: l.serviceNameLabel,
                  hintText: l.serviceNameHint,
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('costField'),
                controller: _costCtrl,
                decoration: InputDecoration(
                  labelText: l.costLabel,
                  hintText: l.costHint,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l.required;
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null) return l.enterNumber;
                  if (n <= 0) return l.mustBeGreaterThanZero;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('currencyField'),
                controller: _currencyCtrl,
                decoration: InputDecoration(labelText: l.currencyLabel),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l.required;
                  final code = v.trim().toUpperCase();
                  if (code.length != 3) {
                    return l.use3LetterCode;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BillingCycle>(
                value: _cycle,
                items: BillingCycle.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(_cycleText(context, e)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _cycle = v ?? _cycle),
                decoration: InputDecoration(labelText: l.billingCycleLabel),
              ),
              if (_cycle == BillingCycle.custom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('intervalField'),
                  controller: _intervalCtrl,
                  decoration: InputDecoration(labelText: l.intervalDaysLabel),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (_cycle != BillingCycle.custom) return null;
                    if (v == null || v.trim().isEmpty) return l.required;
                    final n = int.tryParse(v);
                    if (n == null) return l.enterNumber;
                    if (n <= 0) return l.mustBeGreaterThanZero;
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.nextRenewalDate),
                subtitle: Text(
                  _nextRenewal == null
                      ? l.selectDate
                      : dateFmt.format(_nextRenewal!.toLocal()),
                ),
                trailing: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(l.pick),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('categoryField'),
                controller: _categoryCtrl,
                decoration: InputDecoration(labelText: l.categoryLabel),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('urlField'),
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: l.cancellationUrlLabel,
                  hintText: l.cancellationUrlHint,
                ),
                validator: _validateUrl,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('notesField'),
                controller: _notesCtrl,
                decoration: InputDecoration(labelText: l.notesLabel),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_nextRenewal == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.pleaseSelectNextRenewal)),
                          );
                          return;
                        }

                        setState(() => _saving = true);
                        try {
                          if (isEdit) {
                            // UPDATE
                            final updated = _editing!.copyWith(
                              serviceName: _serviceNameCtrl.text.trim(),
                              cost: double.parse(
                                _costCtrl.text.replaceAll(',', '.'),
                              ),
                              currency: _currencyCtrl.text.trim().toUpperCase(),
                              billingCycle: _cycle,
                              nextRenewalDate: _nextRenewal!,
                              category: _categoryCtrl.text.trim().isEmpty
                                  ? null
                                  : _categoryCtrl.text.trim(),
                              notes: _notesCtrl.text.trim().isEmpty
                                  ? null
                                  : _notesCtrl.text.trim(),
                              cancellationUrl: _urlCtrl.text.trim().isEmpty
                                  ? null
                                  : _urlCtrl.text.trim(),
                              customCycleDays: _cycle == BillingCycle.custom
                                  ? int.parse(_intervalCtrl.text)
                                  : null,
                            );
                            await vm.update(updated, l);
                          } else {
                            await vm.add(
                              serviceName: _serviceNameCtrl.text.trim(),
                              cost: double.parse(
                                _costCtrl.text.replaceAll(',', '.'),
                              ),
                              currency: _currencyCtrl.text.trim().toUpperCase(),
                              cycle: _cycle,
                              nextRenewal: _nextRenewal!,
                              category: _categoryCtrl.text.trim().isEmpty
                                  ? null
                                  : _categoryCtrl.text.trim(),
                              notes: _notesCtrl.text.trim().isEmpty
                                  ? null
                                  : _notesCtrl.text.trim(),
                              url: _urlCtrl.text.trim().isEmpty
                                  ? null
                                  : _urlCtrl.text.trim(),
                              customCycleDays: _cycle == BillingCycle.custom
                                  ? int.parse(_intervalCtrl.text)
                                  : null,
                              l10n: l,
                            );
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit ? l.savedChanges : l.added,
                                ),
                              ),
                            );
                            context.pop();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l.failedWithError(e.toString())),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isEdit ? Icons.save : Icons.check),
                label: Text(isEdit ? l.saveChanges : l.save),
              ),
            ],
          ),
        ),
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
