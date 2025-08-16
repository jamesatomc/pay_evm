import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_service.dart';
import '../models/network_model.dart';

class AddCustomNetworkScreen extends StatefulWidget {
  final NetworkModel? network; // For editing existing network
  
  const AddCustomNetworkScreen({super.key, this.network});

  @override
  State<AddCustomNetworkScreen> createState() => _AddCustomNetworkScreenState();
}

class _AddCustomNetworkScreenState extends State<AddCustomNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final NetworkService _networkService = NetworkService();
  
  late final TextEditingController _nameController;
  late final TextEditingController _rpcUrlController;
  late final TextEditingController _chainIdController;
  late final TextEditingController _currencySymbolController;
  late final TextEditingController _blockExplorerController;
  late final TextEditingController _iconUrlController;
  
  bool _isTestnet = false;
  bool _isLoading = false;
  bool _isTestingConnection = false;
  bool _connectionTestResult = false;
  bool _hasTestedConnection = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing data if editing
    final network = widget.network;
    _nameController = TextEditingController(text: network?.name ?? '');
    _rpcUrlController = TextEditingController(text: network?.rpcUrl ?? '');
    _chainIdController = TextEditingController(text: network?.chainId.toString() ?? '');
    _currencySymbolController = TextEditingController(text: network?.currencySymbol ?? '');
    _blockExplorerController = TextEditingController(text: network?.blockExplorerUrl ?? '');
    _iconUrlController = TextEditingController(text: network?.iconUrl ?? '');
    _isTestnet = network?.isTestnet ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rpcUrlController.dispose();
    _chainIdController.dispose();
    _currencySymbolController.dispose();
    _blockExplorerController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.network != null;

  String get _title => _isEditing ? 'แก้ไขเครือข่าย' : 'เพิ่มเครือข่ายใหม่';

  Future<void> _testConnection() async {
    if (_rpcUrlController.text.trim().isEmpty) {
      _showError('กรุณาใส่ URL ของ RPC');
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _hasTestedConnection = false;
    });

    try {
      final result = await _networkService.testNetworkConnection(_rpcUrlController.text.trim());
      setState(() {
        _connectionTestResult = result;
        _hasTestedConnection = true;
      });

      if (result) {
        _showSuccess('การเชื่อมต่อสำเร็จ!');
      } else {
        _showError('ไม่สามารถเชื่อมต่อได้');
      }
    } catch (e) {
      setState(() {
        _connectionTestResult = false;
        _hasTestedConnection = true;
      });
      _showError('เกิดข้อผิดพลาดในการทดสอบการเชื่อมต่อ: $e');
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveNetwork() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final networkId = _isEditing 
          ? widget.network!.id 
          : 'custom_${DateTime.now().millisecondsSinceEpoch}';

      final network = NetworkModel(
        id: networkId,
        name: _nameController.text.trim(),
        rpcUrl: _rpcUrlController.text.trim(),
        chainId: int.parse(_chainIdController.text.trim()),
        currencySymbol: _currencySymbolController.text.trim().toUpperCase(),
        blockExplorerUrl: _blockExplorerController.text.trim().isEmpty 
            ? null 
            : _blockExplorerController.text.trim(),
        isTestnet: _isTestnet,
        isCustom: true,
        iconPath: 'assets/icons/custom.png',
        iconUrl: _iconUrlController.text.trim().isEmpty 
            ? null 
            : _iconUrlController.text.trim(),
      );

      bool success;
      if (_isEditing) {
        success = await _networkService.updateCustomNetwork(network);
      } else {
        success = await _networkService.addCustomNetwork(network);
      }

      if (success) {
        if (mounted) {
          _showSuccess(_isEditing ? 'อัปเดตเครือข่ายสำเร็จ' : 'เพิ่มเครือข่ายสำเร็จ');
          Navigator.pop(context, true);
        }
      } else {
        _showError(_isEditing 
            ? 'ไม่สามารถอัปเดตเครือข่ายได้' 
            : 'ไม่สามารถเพิ่มเครือข่ายได้ (อาจมีอยู่แล้ว)');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณาใส่$fieldName';
    }
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณาใส่ URL ของ RPC';
    }
    
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (!uri.scheme.startsWith('http'))) {
      return 'กรุณาใส่ URL ที่ถูกต้อง (เริ่มด้วย http:// หรือ https://)';
    }
    
    return null;
  }

  String? _validateChainId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณาใส่ Chain ID';
    }
    
    final chainId = int.tryParse(value.trim());
    if (chainId == null || chainId < 1) {
      return 'กรุณาใส่ Chain ID ที่ถูกต้อง';
    }
    
    return null;
  }

  String? _validateIconUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.scheme.startsWith('http')) {
      return 'กรุณาใส่ URL ของรูป icon ที่ถูกต้อง';
    }
    
    // Check if URL might be an image
    final path = uri.path.toLowerCase();
    if (!path.endsWith('.png') && !path.endsWith('.jpg') && !path.endsWith('.jpeg') && 
        !path.endsWith('.gif') && !path.endsWith('.svg') && !path.endsWith('.webp')) {
      return 'URL ควรเป็นไฟล์รูปภาพ (.png, .jpg, .svg ฯลฯ)';
    }
    
    return null;
  }

  Widget _buildConnectionStatus() {
    if (!_hasTestedConnection) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _connectionTestResult 
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _connectionTestResult ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _connectionTestResult ? Icons.check_circle : Icons.error,
            color: _connectionTestResult ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _connectionTestResult ? 'การเชื่อมต่อสำเร็จ' : 'การเชื่อมต่อล้มเหลว',
            style: TextStyle(
              color: _connectionTestResult ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        centerTitle: true,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveNetwork,
              child: Text(
                _isEditing ? 'อัปเดต' : 'บันทึก',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Network Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อเครือข่าย *',
                      hintText: 'เช่น My Custom Chain',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (value) => _validateRequired(value, 'ชื่อเครือข่าย'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // RPC URL
                  TextFormField(
                    controller: _rpcUrlController,
                    decoration: InputDecoration(
                      labelText: 'RPC URL *',
                      hintText: 'https://rpc.example.com',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _isTestingConnection
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.wifi_find),
                              onPressed: _testConnection,
                              tooltip: 'ทดสอบการเชื่อมต่อ',
                            ),
                    ),
                    validator: _validateUrl,
                    onChanged: (_) {
                      if (_hasTestedConnection) {
                        setState(() {
                          _hasTestedConnection = false;
                          _connectionTestResult = false;
                        });
                      }
                    },
                  ),
                  
                  _buildConnectionStatus(),
                  
                  const SizedBox(height: 16),
                  
                  // Chain ID
                  TextFormField(
                    controller: _chainIdController,
                    decoration: const InputDecoration(
                      labelText: 'Chain ID *',
                      hintText: 'เช่น 1337',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validateChainId,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Currency Symbol
                  TextFormField(
                    controller: _currencySymbolController,
                    decoration: const InputDecoration(
                      labelText: 'สัญลักษณ์เงินตรา *',
                      hintText: 'เช่น ETH, BNB, MATIC',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) => _validateRequired(value, 'สัญลักษณ์เงินตรา'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Block Explorer URL (Optional)
                  TextFormField(
                    controller: _blockExplorerController,
                    decoration: const InputDecoration(
                      labelText: 'Block Explorer URL (ไม่บังคับ)',
                      hintText: 'https://explorer.example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Icon URL (Optional)
                  TextFormField(
                    controller: _iconUrlController,
                    decoration: InputDecoration(
                      labelText: 'Icon URL (ไม่บังคับ)',
                      hintText: 'https://example.com/icon.png',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.image),
                      suffixIcon: _iconUrlController.text.trim().isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.transparent,
                                child: ClipOval(
                                  child: Image.network(
                                    _iconUrlController.text.trim(),
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error, size: 20, color: Colors.red);
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    validator: _validateIconUrl,
                    onChanged: (_) {
                      setState(() {}); // Rebuild to show/hide preview
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Testnet Switch
                  Card(
                    child: SwitchListTile(
                      title: const Text('เครือข่าย Testnet'),
                      subtitle: const Text('เปิดใช้หากเป็นเครือข่ายทดสอบ'),
                      value: _isTestnet,
                      onChanged: (value) => setState(() => _isTestnet = value),
                      secondary: Icon(
                        _isTestnet ? Icons.code : Icons.public,
                        color: _isTestnet ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveNetwork,
                    icon: Icon(_isEditing ? Icons.update : Icons.add),
                    label: Text(_isEditing ? 'อัปเดตเครือข่าย' : 'เพิ่มเครือข่าย'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Help Text
                  Card(
                    color: Colors.blue.withOpacity(0.1),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'ข้อมูลที่ต้องการ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('• ชื่อเครือข่าย: ชื่อที่จะแสดงในแอป'),
                          Text('• RPC URL: URL สำหรับเชื่อมต่อกับเครือข่าย'),
                          Text('• Chain ID: รหัสประจำเครือข่าย'),
                          Text('• สัญลักษณ์เงินตรา: สัญลักษณ์ของเหรียญหลัก'),
                          Text('• Block Explorer: URL สำหรับดูข้อมูลธุรกรรม (ไม่บังคับ)'),
                          Text('• Icon URL: ลิงค์รูป icon ของเครือข่าย (ไม่บังคับ)'),
                          SizedBox(height: 4),
                          Text('  รองรับไฟล์: .png, .jpg, .svg, .webp', 
                               style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
