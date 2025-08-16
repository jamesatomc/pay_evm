import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../models/wallet_model.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> {
  final WalletService _walletService = WalletService();
  List<WalletModel> _wallets = [];
  WalletModel? _activeWallet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  @override
  void dispose() {
    _walletService.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    try {
      final wallets = await _walletService.getWallets();
      final activeWallet = await _walletService.getActiveWallet();
      
      setState(() {
        _wallets = wallets;
        _activeWallet = activeWallet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('เกิดข้อผิดพลาดในการโหลดกระเป๋า: $e');
    }
  }

  Future<void> _switchWallet(String address) async {
    try {
      await _walletService.switchWallet(address);
      final activeWallet = await _walletService.getActiveWallet();
      setState(() => _activeWallet = activeWallet);
      
      if (mounted) {
        Navigator.pop(context, activeWallet);
        _showSuccess('เปลี่ยนกระเป๋าสำเร็จ');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการเปลี่ยนกระเป๋า: $e');
    }
  }

  Future<void> _deleteWallet(String address) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณแน่ใจหรือไม่ที่จะลบกระเป๋านี้? การดำเนินการนี้ไม่สามารถยกเลิกได้'),
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
    );

    if (confirmed == true) {
      try {
        await _walletService.deleteWallet(address);
        await _loadWallets(); // Reload wallets
        _showSuccess('ลบกระเป๋าสำเร็จ');
      } catch (e) {
        _showError('เกิดข้อผิดพลาดในการลบกระเป๋า: $e');
      }
    }
  }

  void _showWalletDetails(WalletModel wallet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(wallet.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Address:', wallet.address),
            const SizedBox(height: 8),
            _buildDetailRow('Private Key:', wallet.privateKey, isPrivate: true),
            const SizedBox(height: 8),
            if (wallet.mnemonic.isNotEmpty)
              _buildDetailRow('Mnemonic:', wallet.mnemonic, isPrivate: true),
            const SizedBox(height: 8),
            _buildDetailRow('Created:', _formatDate(wallet.createdAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrivate = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPrivate ? _maskString(value) : value,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกแล้ว')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  String _maskString(String value) {
    if (value.length <= 8) return value;
    return '${value.substring(0, 4)}${'*' * 8}${value.substring(value.length - 4)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('กระเป๋าของฉัน'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
              ? _buildEmptyState()
              : _buildWalletList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีกระเป๋า',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'เริ่มต้นโดยการสร้างกระเป๋าใหม่',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _wallets.length,
      itemBuilder: (context, index) {
        final wallet = _wallets[index];
        final isActive = _activeWallet?.address == wallet.address;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green : Colors.grey,
              child: Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(wallet.name)),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'กำลังใช้',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${wallet.address.substring(0, 6)}...${wallet.address.substring(wallet.address.length - 4)}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'switch':
                    if (!isActive) _switchWallet(wallet.address);
                    break;
                  case 'details':
                    _showWalletDetails(wallet);
                    break;
                  case 'delete':
                    _deleteWallet(wallet.address);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!isActive)
                  const PopupMenuItem(
                    value: 'switch',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz),
                        SizedBox(width: 8),
                        Text('เปลี่ยนเป็นกระเป๋าหลัก'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info),
                      SizedBox(width: 8),
                      Text('ดูรายละเอียด'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('ลบกระเป๋า', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              if (!isActive) {
                _switchWallet(wallet.address);
              }
            },
          ),
        );
      },
    );
  }
}
