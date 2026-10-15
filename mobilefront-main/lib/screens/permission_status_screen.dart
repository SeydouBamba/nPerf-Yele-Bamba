import 'package:flutter/material.dart';

import '../services/permission_status_service.dart';
import '../theme/yele_theme.dart';
import '../widgets/yele_scaffold.dart';

class PermissionStatusScreen extends StatefulWidget {
  const PermissionStatusScreen({super.key});

  @override
  State<PermissionStatusScreen> createState() => _PermissionStatusScreenState();
}

class _PermissionStatusScreenState extends State<PermissionStatusScreen> {
  final _service = PermissionStatusService();
  Map<String, bool?>? _statuses;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = await _service.readStatuses();
      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return YeleScaffold(
      title: 'Permissions',
      route: '/settings',
      body: Container(
        color: YeleColors.panel,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Impossible de lire les permissions : $_error'),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : ListView(
                children: [
                  _permissionTile('Localisation', _statuses!['location']),
                  _permissionTile(
                    'Téléphone et réseau mobile',
                    _statuses!['phone'],
                  ),
                  _permissionTile('Notifications', _statuses!['notifications']),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser les permissions'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _permissionTile(String title, bool? granted) {
    final label = granted == null
        ? 'Non applicable sur cette plateforme'
        : granted
        ? 'Autorisée'
        : 'Refusée ou désactivée';
    return ListTile(
      title: Text(title, style: const TextStyle(color: YeleColors.ink)),
      subtitle: Text(label),
      trailing: Icon(
        granted == null
            ? Icons.remove_circle_outline
            : granted
            ? Icons.check_circle
            : Icons.cancel,
        color: granted == null
            ? YeleColors.muted
            : granted
            ? YeleColors.good
            : YeleColors.danger,
      ),
    );
  }
}
