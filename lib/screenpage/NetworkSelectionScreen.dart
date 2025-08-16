import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../models/network_model.dart';
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
      _showError('เกิดข้อผิดพลาดในการโหลดเครือข่าย: $e');
    }
  }

  Future<void> _selectNetwork(NetworkModel network) async {
    try {
      await _networkService.setActiveNetwork(network.id);
      setState(() => _activeNetwork = network);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนไปใช้เครือข่าย ${network.name} แล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการเปลี่ยนเครือข่าย: $e');
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบเครือข่าย ${network.name} แล้ว'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        _showError('ไม่สามารถลบเครือข่ายได้');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการลบเครือข่าย: $e');
    }
  }

  Future<bool> _showDeleteConfirmDialog(String networkName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบเครือข่าย "$networkName" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addCustomNetwork() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCustomNetworkScreen(),
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
        leading: CircleAvatar(
          backgroundColor: _getNetworkColor(network),
          child: Icon(
            _getNetworkIcon(network),
            color: Colors.white,
            size: 20,
          ),
        ),
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
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Testnet',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
            if (showMenu)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      // TODO: Implement edit functionality
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
                        Text('แก้ไข'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('ลบ', style: TextStyle(color: Colors.red)),
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

  Color _getNetworkColor(NetworkModel network) {
    if (network.isCustom) return Colors.blue;
    if (network.isTestnet) return Colors.orange;
    
    switch (network.id) {
      case 'ethereum':
      case 'sepolia':
        return const Color(0xFF627EEA);
      case 'bsc':
      case 'bsc-testnet':
        return const Color(0xFFF3BA2F);
      case 'polygon':
      case 'mumbai':
        return const Color(0xFF8247E5);
      case 'avalanche':
      case 'fuji':
        return const Color(0xFFE84142);
      case 'fantom':
      case 'fantom-testnet':
        return const Color(0xFF1969FF);
      default:
        return Colors.grey;
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
      case 'polygon':
      case 'mumbai':
        return Icons.hexagon;
      case 'avalanche':
      case 'fuji':
        return Icons.ac_unit;
      case 'fantom':
      case 'fantom-testnet':
        return Icons.speed;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกเครือข่าย'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCustomNetwork,
            tooltip: 'เพิ่มเครือข่ายที่กำหนดเอง',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNetworks,
              child: ListView(
                children: [
                  // Predefined Networks Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'เครือข่ายหลัก',
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
                        'เครือข่าย Testnet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                        'เครือข่ายที่กำหนดเอง',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                      label: const Text('เพิ่มเครือข่ายที่กำหนดเอง'),
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
