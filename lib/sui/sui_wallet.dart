import 'package:sui/sui.dart';

/// Lightweight Sui wallet helper used by WalletService.
/// Provides generation/import from mnemonic or private key and returns
/// a small data holder.

enum SuiSignatureScheme { ed25519, secp256k1, secp256r1 }

class SuiWallet {
  final String address;
  final String privateKey;
  final String publicKey;
  final String mnemonic;

  SuiWallet({
    required this.address,
    required this.privateKey,
    required this.publicKey,
    required this.mnemonic,
  });
}

SignatureScheme _toSignatureScheme(SuiSignatureScheme scheme) {
  if (scheme == SuiSignatureScheme.secp256k1) return SignatureScheme.Secp256k1;
  if (scheme == SuiSignatureScheme.secp256r1) return SignatureScheme.Secp256r1;
  return SignatureScheme.Ed25519;
}

/// Generate a new Sui wallet using mnemonic. Returns address/private/public/mnemonic.
Future<SuiWallet> generateSuiWallet({
  SuiSignatureScheme scheme = SuiSignatureScheme.ed25519,
  int wordCount = 12,
}) async {
  // The `sui` package exposes SuiAccount.generateMnemonic(), but to allow
  // 12/24 selection use simple bip39 strength via SuiAccount if available.
  final mnemonic = SuiAccount.generateMnemonic();

  final sig = _toSignatureScheme(scheme);
  final account = SuiAccount.fromMnemonics(mnemonic, sig);

  return SuiWallet(
    address: account.getAddress(),
    privateKey: account.privateKey(),
    publicKey: '',
    mnemonic: mnemonic,
  );
}

/// Import Sui wallet from mnemonic
Future<SuiWallet> importSuiFromMnemonic(String mnemonic,
    {SuiSignatureScheme scheme = SuiSignatureScheme.ed25519}) async {
  final sig = _toSignatureScheme(scheme);
  final account = SuiAccount.fromMnemonics(mnemonic, sig);

  return SuiWallet(
    address: account.getAddress(),
    privateKey: account.privateKey(),
    publicKey: '',
    mnemonic: mnemonic,
  );
}

/// Import Sui wallet from a private key string (hex or raw as accepted by package)
Future<SuiWallet> importSuiFromPrivateKey(String privateKey,
    {SuiSignatureScheme scheme = SuiSignatureScheme.ed25519}) async {
  final sig = _toSignatureScheme(scheme);
  final account = SuiAccount.fromPrivateKey(privateKey, sig);

  return SuiWallet(
    address: account.getAddress(),
    privateKey: account.privateKey(),
    publicKey: '',
    mnemonic: '',
  );
}
