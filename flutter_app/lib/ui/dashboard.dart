import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/relay_state.dart';
import '../api/models.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final relayState = Provider.of<RelayState>(context);
    final status = relayState.status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OhMyPhone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: relayState.pollStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection status card - persistent at top
            _buildConnectionStatusCard(context, relayState),
            const SizedBox(height: 16),
            
            // Radio controls
            _buildControlCard(
              context: context,
              title: 'Mobile Data',
              icon: Icons.signal_cellular_alt,
              value: status?.dataEnabled ?? false,
              onToggle: () => relayState.toggleDataEnabled(),
              enabled: status != null,
            ),
            const SizedBox(height: 16),
            
            _buildControlCard(
              context: context,
              title: 'Airplane Mode',
              icon: Icons.flight,
              value: status?.airplaneMode ?? false,
              onToggle: () => relayState.toggleAirplaneMode(),
              enabled: status != null,
            ),
            const SizedBox(height: 16),
            
            // Call forwarding card
            _buildCallForwardingCard(context, relayState, status),
            const SizedBox(height: 16),
            
            // Device info cards
            if (status != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      context: context,
                      title: 'Battery',
                      icon: Icons.battery_std,
                      value: '${status.battery}%',
                      color: _getBatteryColor(status.battery),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      context: context,
                      title: 'Signal',
                      icon: Icons.signal_cellular_4_bar,
                      value: '${status.signal}%',
                      color: _getSignalColor(status.signal),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(BuildContext context, RelayState relayState) {
    final theme = Theme.of(context);
    final status = relayState.connectionStatus;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status) {
      case ConnectionStatus.online:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Connected';
        break;
      case ConnectionStatus.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Connecting...';
        break;
      case ConnectionStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Error: ${relayState.errorMessage ?? "Unknown"}';
        break;
      case ConnectionStatus.offline:
        statusColor = Colors.grey;
        statusIcon = Icons.cloud_off;
        statusText = 'Offline';
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (relayState.lastSuccessfulPoll != null)
                        Text(
                          'Last update: ${_formatTime(relayState.lastSuccessfulPoll!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool value,
    required VoidCallback onToggle,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: enabled ? onToggle : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: enabled
                    ? (value ? theme.colorScheme.primary : theme.colorScheme.onSurface)
                    : theme.disabledColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: enabled ? null : theme.disabledColor,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: enabled ? (_) => onToggle() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallForwardingCard(
      BuildContext context, RelayState relayState, DeviceStatus? status) {
    final theme = Theme.of(context);
    final isActive = status?.callForwardingActive ?? false;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_forwarded,
                  size: 32,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Call Forwarding',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: status != null
                      ? (_) => _showForwardingDialog(context, relayState, isActive)
                      : null,
                ),
              ],
            ),
            if (isActive && status?.forwardingNumber != null) ...[
              const SizedBox(height: 8),
              Text(
                'Forwarding to: ${status!.forwardingNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForwardingDialog(
      BuildContext context, RelayState relayState, bool isActive) {
    if (isActive) {
      // Disable forwarding
      relayState.toggleCallForwarding();
    } else {
      // Enable forwarding - show dialog for number
      final controller = TextEditingController();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Call Forwarding'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter number to forward calls to',
            ),
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final number = controller.text.trim();
                if (number.isNotEmpty) {
                  relayState.toggleCallForwarding(number: number);
                  Navigator.pop(context);
                }
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      );
    }
  }

  Color _getBatteryColor(int battery) {
    if (battery > 60) return Colors.green;
    if (battery > 30) return Colors.orange;
    return Colors.red;
  }

  Color _getSignalColor(int signal) {
    if (signal > 60) return Colors.green;
    if (signal > 30) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
