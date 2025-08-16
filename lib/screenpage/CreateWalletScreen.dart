import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final WalletService _walletService = WalletService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  
  bool _isLoading = false;
  int _selectedTab = 0; // 0: Create, 1: Import Mnemonic, 2: Import Private Key

  @override
  void dispose() {
    _nameController.dispose();
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    _walletService.dispose();
    super.dispose();
  }

  Future<void> _createNewWallet() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('กรุณาใส่ชื่อกระเป๋า');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wallet = await _walletService.createNewWallet(_nameController.text.trim());
      if (mounted) {
        Navigator.pop(context, wallet);
        _showSuccess('สร้างกระเป๋าใหม่สำเร็จ!');
      }
    } catch (e) {
      if (mounted) {
        _showError('เกิดข้อผิดพลาดในการสร้างกระเป๋า: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromMnemonic() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('กรุณาใส่ชื่อกระเป๋า');
      return;
    }

    if (_mnemonicController.text.trim().isEmpty) {
      _showError('กรุณาใส่ Mnemonic phrase');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wallet = await _walletService.importWalletFromMnemonic(
        _mnemonicController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, wallet);
        _showSuccess('นำเข้ากระเป๋าสำเร็จ!');
      }
    } catch (e) {
      if (mounted) {
        _showError('เกิดข้อผิดพลาดในการนำเข้ากระเป๋า: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromPrivateKey() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('กรุณาใส่ชื่อกระเป๋า');
      return;
    }

    if (_privateKeyController.text.trim().isEmpty) {
      _showError('กรุณาใส่ Private Key');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wallet = await _walletService.importWalletFromPrivateKey(
        _privateKeyController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, wallet);
        _showSuccess('นำเข้ากระเป๋าสำเร็จ!');
      }
    } catch (e) {
      if (mounted) {
        _showError('เกิดข้อผิดพลาดในการนำเข้ากระเป๋า: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
        title: const Text('เพิ่มกระเป๋า'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'สร้างใหม่',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 0 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Mnemonic',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 1 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 2 ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Private Key',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 2 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wallet name field (common for all tabs)
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'ชื่อกระเป๋า',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
        ),
        const SizedBox(height: 16),
        
        // Tab-specific content
        if (_selectedTab == 0) _buildCreateNewTab(),
        if (_selectedTab == 1) _buildImportMnemonicTab(),
        if (_selectedTab == 2) _buildImportPrivateKeyTab(),
        
        const Spacer(),
        
        // Action button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _getActionCallback(),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_getButtonText()),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateNewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'สร้างกระเป๋าใหม่',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• ระบบจะสร้าง Mnemonic phrase ให้คุณโดยอัตโนมัติ\n'
                  '• กรุณาบันทึก Mnemonic phrase ให้ปลอดภัย\n'
                  '• อย่าแชร์ Mnemonic phrase กับใครเด็ดขาด',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportMnemonicTab() {
    return Column(
      children: [
        TextField(
          controller: _mnemonicController,
          decoration: const InputDecoration(
            labelText: 'Mnemonic Phrase (12 คำ)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
            helperText: 'ใส่ Mnemonic phrase คั่นด้วยเว้นวรรค',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ตรวจสอบ Mnemonic phrase ให้ถูกต้องก่อนดำเนินการ',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportPrivateKeyTab() {
    return Column(
      children: [
        TextField(
          controller: _privateKeyController,
          decoration: const InputDecoration(
            labelText: 'Private Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
            helperText: 'ใส่ Private Key (ขึ้นต้นด้วย 0x หรือไม่ก็ได้)',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.red[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Private Key คือข้อมูลที่สำคัญมาก อย่าแชร์กับใครเด็ดขาด',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  VoidCallback? _getActionCallback() {
    switch (_selectedTab) {
      case 0:
        return _createNewWallet;
      case 1:
        return _importFromMnemonic;
      case 2:
        return _importFromPrivateKey;
      default:
        return null;
    }
  }

  String _getButtonText() {
    switch (_selectedTab) {
      case 0:
        return 'สร้างกระเป๋าใหม่';
      case 1:
        return 'นำเข้าจาก Mnemonic';
      case 2:
        return 'นำเข้าจาก Private Key';
      default:
        return 'ดำเนินการ';
    }
  }
}
