import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/relay_state.dart';
import '../config/app_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverController = TextEditingController();
  final _secretController = TextEditingController();
  double _pollInterval = 15;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final serverUrl = await AppConfig.getServerUrl();
    final secret = await AppConfig.getSecret();
    final pollInterval = await AppConfig.getPollInterval();

    setState(() {
      _serverController.text = serverUrl;
      _secretController.text = secret;
      _pollInterval = pollInterval.toDouble();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relayState = Provider.of<RelayState>(context, listen: false);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => _saveSettings(relayState),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server Configuration Card
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dns, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Daemon Configuration',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://100.x.x.x:8080',
                      helperText: 'Tailscale IP or local address',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _secretController,
                    decoration: const InputDecoration(
                      labelText: 'HMAC Secret',
                      hintText: 'Enter shared secret',
                      helperText: 'Must match daemon config.toml',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Polling Configuration Card
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.refresh, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Polling Interval',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _pollInterval,
                          min: 5,
                          max: 60,
                          divisions: 11,
                          label: '${_pollInterval.toInt()}s',
                          onChanged: (value) {
                            setState(() => _pollInterval = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${_pollInterval.toInt()}s',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Update status every ${_pollInterval.toInt()} seconds',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Developer Info Card
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'About',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    'Version',
                    '1.0.0',
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    'Protocol',
                    'HMAC-SHA256',
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    'Connection',
                    'HTTP over Tailscale VPN',
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    'Architecture',
                    'Dual-phone relay system',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test Connection Button
          FilledButton.icon(
            onPressed: () => _testConnection(relayState),
            icon: const Icon(Icons.network_check),
            label: const Text('Test Connection'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings(RelayState relayState) async {
    final serverUrl = _serverController.text.trim();
    final secret = _secretController.text.trim();

    if (serverUrl.isEmpty || secret.isEmpty) {
      _showMessage('Please fill in all required fields');
      return;
    }

    // Validate URL format
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      _showMessage('Server URL must start with http:// or https://');
      return;
    }

    await relayState.updateConfiguration(serverUrl, secret);
    await relayState.updatePollInterval(_pollInterval.toInt());

    if (mounted) {
      _showMessage('Settings saved successfully');
      Navigator.pop(context);
    }
  }

  Future<void> _testConnection(RelayState relayState) async {
    final serverUrl = _serverController.text.trim();
    final secret = _secretController.text.trim();

    if (serverUrl.isEmpty || secret.isEmpty) {
      _showMessage('Please configure server URL and secret first');
      return;
    }

    // Temporarily update client to test
    await relayState.updateConfiguration(serverUrl, secret);

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Testing connection...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Test connection
    await relayState.pollStatus();

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (relayState.connectionStatus == ConnectionStatus.online) {
      _showMessage('Connection successful!', isError: false);
    } else {
      _showMessage(
        'Connection failed: ${relayState.errorMessage ?? "Unknown error"}',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _secretController.dispose();
    super.dispose();
  }
}
