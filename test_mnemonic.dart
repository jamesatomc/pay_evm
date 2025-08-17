import 'package:bip39/bip39.dart' as bip39;
import 'package:pointycastle/export.dart';
import 'package:web3dart/web3dart.dart';
import 'dart:typed_data';

void main() {
  print('Testing mnemonic to private key generation...');
  print('=' * 60);
  
  // Test different mnemonics
  for (int i = 1; i <= 5; i++) {
    // Generate different mnemonic each time
    final mnemonic = bip39.generateMnemonic(strength: 128);
    print('\nTest $i:');
    print('Mnemonic: ${mnemonic.substring(0, 30)}...');
    
    // Convert to seed
    final seed = bip39.mnemonicToSeed(mnemonic);
    print('Seed preview: ${seed.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}...');
    
    // Method 1: Direct seed (first 32 bytes)
    var privateKeyBytes = Uint8List.fromList(seed.take(32).toList());
    
    // Method 2: If invalid, use HMAC
    if (_isInvalidPrivateKey(privateKeyBytes)) {
      print('Direct seed invalid, using HMAC...');
      final hmac = HMac(SHA256Digest(), 64);
      final key = Uint8List.fromList(seed);
      final message = Uint8List.fromList('m/44\'/60\'/0\'/0/0'.codeUnits);
      
      hmac.init(KeyParameter(key));
      hmac.update(message, 0, message.length);
      
      privateKeyBytes = Uint8List(32);
      hmac.doFinal(privateKeyBytes, 0);
    }
    
    print('Private key: ${privateKeyBytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}...');
    
    // Create credentials and get address
    try {
      final credentials = EthPrivateKey(privateKeyBytes);
      final address = credentials.address.hex;
      print('Address: $address');
    } catch (e) {
      print('Error creating credentials: $e');
    }
  }
}

bool _isInvalidPrivateKey(Uint8List privateKey) {
  // Check if all bytes are zero
  if (privateKey.every((byte) => byte == 0)) {
    return true;
  }
  
  // Check if it's too large (greater than secp256k1 curve order)
  final maxBytes = [
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
    0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
    0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
  ];
  
  for (int i = 0; i < 32; i++) {
    if (privateKey[i] > maxBytes[i]) {
      return true;
    } else if (privateKey[i] < maxBytes[i]) {
      return false;
    }
  }
  
  return false;
}
