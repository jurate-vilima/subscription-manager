import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:subscription_manager/utils/export_import.dart';
import 'package:subscription_manager/viewmodels/settings_viewmodel.dart';
import 'package:subscription_manager/viewmodels/subscription_list_viewmodel.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _currencyCtrl;
  late int _leadDays;
  late TimeOfDay _notifyAt;
  late String _themeMode;
  late String _localeCode;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsViewModel>().state;
    _currencyCtrl = TextEditingController(text: s.defaultCurrency);
    _leadDays = s.leadDays;
    _notifyAt = TimeOfDay(hour: s.notifyHour, minute: s.notifyMinute);
    _themeMode = s.themeMode;
    _localeCode = s.localeCode;
  }

  @override
  void dispose() {
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifyAt,
    );
    if (picked != null) setState(() => _notifyAt = picked);
  }

  Future<void> _save() async {
    final vm = context.read<SettingsViewModel>();
    final l = AppLocalizations.of(context)!;
    try {
      await vm.update(
        defaultCurrency: _currencyCtrl.text.trim().isEmpty
            ? 'EUR'
            : _currencyCtrl.text.trim().toUpperCase(),
        leadDays: _leadDays,
        themeMode: _themeMode,
        localeCode: _localeCode,
        notifyHour: _notifyAt.hour,
        notifyMinute: _notifyAt.minute,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.settingsSaved)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.failedWithError(e.toString()))));
    }
  }

  Future<void> _exportData() async {
    final l = AppLocalizations.of(context)!;
    try {
      final subs = context.read<SubscriptionListViewModel>().items;
      final jsonStr = ExportImport.exportToJson(subs);
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l.selectDestination,
      );
      if (dirPath == null) return;
      final file = File('$dirPath/subscriptions.json');
      await file.writeAsString(jsonStr);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.exportedTo(file.path))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.exportFailed(e.toString()))));
    }
  }

  Future<void> _importData() async {
    final l = AppLocalizations.of(context)!;
    final vm = context.read<SubscriptionListViewModel>();
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l.selectBackupFile,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (!mounted) return;
      if (result == null || result.files.single.path == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.noBackupFound)));
        return;
      }
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      if (!mounted) return;
      final subs = ExportImport.importFromJson(jsonStr);
      await vm.replaceAllFromImport(subs);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.importSuccessful)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.importFailed(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _currencyCtrl,
            decoration: InputDecoration(labelText: l.defaultCurrencyLabel),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('themeModeDropdown'),
            value: _themeMode,
            decoration: InputDecoration(labelText: l.themeModeLabel),
            items: [
              DropdownMenuItem(value: 'system', child: Text(l.themeModeSystem)),
              DropdownMenuItem(value: 'light', child: Text(l.themeModeLight)),
              DropdownMenuItem(value: 'dark', child: Text(l.themeModeDark)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _themeMode = v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('localeDropdown'),
            value: _localeCode,
            decoration: InputDecoration(labelText: l.languageLabel),
            items: [
              DropdownMenuItem(value: 'en', child: Text(l.languageEnglish)),
              DropdownMenuItem(value: 'lv', child: Text(l.languageLatvian)),
              DropdownMenuItem(value: 'ru', child: Text(l.languageRussian)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _localeCode = v);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(l.reminderLeadTime),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: _leadDays.toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    final value = int.tryParse(v);
                    if (value != null) {
                      setState(() => _leadDays = value.clamp(0, 30).toInt());
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.notifyAtTime),
            subtitle: Text(_notifyAt.format(context)),
            trailing: OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(l.pick),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l.save),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _exportData,
            icon: const Icon(Icons.upload),
            label: Text(l.exportSubscriptions),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _importData,
            icon: const Icon(Icons.download),
            label: Text(l.importSubscriptions),
          ),
        ],
      ),
    );
  }
}
