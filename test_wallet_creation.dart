import 'package:flutter/material.dart';
import 'lib/services/wallet_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Testing wallet creation to ensure unique addresses...');
  print('=' * 60);
  
  final walletService = WalletService();
  
  // Test creating 5 wallets with 12-word mnemonic
  print('\n🔹 Testing 12-word mnemonic wallets:');
  for (int i = 1; i <= 5; i++) {
    try {
      final wallet = await walletService.createNewWallet(
        'Test Wallet $i',
        wordCount: 12,
      );
      print('Wallet $i: ${wallet.address} (${wallet.mnemonic.split(' ').length} words)');
    } catch (e) {
      print('Error creating wallet $i: $e');
    }
  }
  
  // Test creating 3 wallets with 24-word mnemonic
  print('\n🔹 Testing 24-word mnemonic wallets:');
  for (int i = 1; i <= 3; i++) {
    try {
      final wallet = await walletService.createNewWallet(
        'Test Wallet 24-$i',
        wordCount: 24,
      );
      print('Wallet $i: ${wallet.address} (${wallet.mnemonic.split(' ').length} words)');
    } catch (e) {
      print('Error creating wallet $i: $e');
    }
  }
  
  print('\n${'=' * 60}');
  print('Test completed! Check if all addresses are unique.');
}
