// ignore: file_names
import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../models/network_model.dart';
import '../utils/app_theme.dart';
import 'AddCustomNetworkScreen.dart';

class NetworkSelectionScreen extends StatefulWidget {
  const NetworkSelectionScreen({super.key});

  @override
  State<NetworkSelectionScreen> createState() => _NetworkSelectionScreenState();
}

class _NetworkSelectionScreenState extends State<NetworkSelectionScreen> {
  final NetworkService _networkService = NetworkService();
  List<NetworkModel> _predefinedNetworks = [];
  List<NetworkModel> _customNetworks = [];
  NetworkModel? _activeNetwork;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    setState(() => _isLoading = true);

    try {
      final predefined = _networkService.getPredefinedNetworks();
      final custom = await _networkService.getCustomNetworks();
      final active = await _networkService.getActiveNetwork();

      setState(() {
        _predefinedNetworks = predefined;
        _customNetworks = custom;
        _activeNetwork = active;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      //eng
      _showError('Error loading networks: $e');
    }
  }

  Future<void> _selectNetwork(NetworkModel network) async {
    try {
      await _networkService.setActiveNetwork(network.id);
      setState(() => _activeNetwork = network);

      // Show success message
      if (mounted) {
        _showSuccess('Switched to network ${network.name}');

        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Error switching networks: $e');
    }
  }

  Future<void> _deleteCustomNetwork(NetworkModel network) async {
    final confirmed = await _showDeleteConfirmDialog(network.name);
    if (!confirmed) return;

    try {
      final success = await _networkService.removeCustomNetwork(network.id);
      if (success) {
        await _loadNetworks();
        if (mounted) {
          _showSuccess('Deleted network ${network.name}');
        }
      } else {
        _showError('Unable to delete network');
      }
    } catch (e) {
      _showError('Error deleting network: $e');
    }
  }

  Future<bool> _showDeleteConfirmDialog(String networkName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete the network "$networkName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.secondaryColor),
      );
    }
  }

  Future<void> _addCustomNetwork() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddCustomNetworkScreen()),
    );

    if (result == true) {
      await _loadNetworks();
    }
  }

  Future<void> _editCustomNetwork(NetworkModel network) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomNetworkScreen(network: network),
      ),
    );

    if (result == true) {
      await _loadNetworks();
    }
  }

  Widget _buildNetworkTile(NetworkModel network, {bool showMenu = false}) {
    final isActive = _activeNetwork?.id == network.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isActive ? 4 : 1,
      color: isActive ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: _buildNetworkAvatar(network),
        title: Text(
          network.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chain ID: ${network.chainId}'),
            Text('Currency: ${network.currencySymbol}'),
            if (network.isTestnet)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Testnet',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) const Icon(Icons.check_circle, color: Colors.green),
            if (showMenu)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editCustomNetwork(network);
                      break;
                    case 'delete':
                      _deleteCustomNetwork(network);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.errorColor),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        onTap: isActive ? null : () => _selectNetwork(network),
      ),
    );
  }

  Widget _buildNetworkAvatar(NetworkModel network) {
    // If network has a custom icon URL, use it
    if (network.iconUrl != null && network.iconUrl!.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: _getNetworkColor(network),
        child: ClipOval(
          child: Image.network(
            network.iconUrl!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to default icon if URL fails
              return Icon(
                _getNetworkIcon(network),
                color: Colors.white,
                size: 20,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
          ),
        ),
      );
    }

    // Default icon
    return CircleAvatar(
      backgroundColor: _getNetworkColor(network),
      child: Icon(_getNetworkIcon(network), color: Colors.white, size: 20),
    );
  }

  Color _getNetworkColor(NetworkModel network) {
  if (network.isCustom) return AppTheme.primaryColor;
    if (network.isTestnet) return Colors.orange;

    switch (network.id) {
      case 'ethereum':
      case 'sepolia':
  return AppTheme.primaryColor;
      case 'bsc':
      case 'bsc-testnet':
        return const Color(0xFFF3BA2F);
      case 'alpen-testnet':
        return const Color.fromARGB(255, 0, 0, 0); // Bitcoin orange
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getNetworkIcon(NetworkModel network) {
    if (network.isCustom) return Icons.lan;
    if (network.isTestnet) return Icons.code;

    switch (network.id) {
      case 'ethereum':
      case 'sepolia':
        return Icons.currency_bitcoin; // Use as Ethereum placeholder
      case 'bsc':
      case 'bsc-testnet':
        return Icons.account_balance;
      case 'alpen-testnet':
        return Icons.currency_bitcoin; // Bitcoin icon for sBTC
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const Text('Select Network')],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    body: _isLoading
      ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)))
          : RefreshIndicator(
              onRefresh: _loadNetworks,
              child: ListView(
                children: [
                  // Predefined Networks Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Main Networks',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._predefinedNetworks
                      .where((n) => !n.isTestnet)
                      .map((network) => _buildNetworkTile(network)),

                  // Testnet Networks Section
                  if (_predefinedNetworks.any((n) => n.isTestnet)) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Testnet Networks',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._predefinedNetworks
                        .where((n) => n.isTestnet)
                        .map((network) => _buildNetworkTile(network)),
                  ],

                  // Custom Networks Section
                  if (_customNetworks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Custom Networks',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._customNetworks.map(
                      (network) => _buildNetworkTile(network, showMenu: true),
                    ),
                  ],

                  // Add Custom Network Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton.icon(
                      onPressed: _addCustomNetwork,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Custom Network'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
