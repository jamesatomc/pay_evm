import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kanaripay/utils/custom_widgets.dart';
import '../models/wallet_model.dart';
import '../utils/app_theme.dart';


class ShowMnemonicScreen extends StatelessWidget {
  final WalletModel wallet;

  const ShowMnemonicScreen({super.key, required this.wallet});

  void _copyMnemonic(BuildContext context) {
    Clipboard.setData(ClipboardData(text: wallet.mnemonic));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied Mnemonic')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = wallet.mnemonic.split(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Wallet'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning section
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.errorColor.withOpacity(0.15)
                  : AppTheme.errorColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.security, 
                      color: AppTheme.errorColor, 
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Important!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      //eng
                      '• Save this Mnemonic phrase securely\n'
                      '• Do not share with anyone\n'
                      '• If Mnemonic is lost, wallet cannot be recovered\n'
                      '• Write it down and keep it in a safe place',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Wallet info
            Text(
              'Wallet: ${wallet.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Mnemonic Phrase (12 Words)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 12),
            
            // Mnemonic words grid
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Theme.of(context).iconTheme.color ?? Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              words[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Copy button
            CustomButton(
              text: 'Copy Mnemonic',
              onPressed: () => _copyMnemonic(context),
              icon: Icons.copy,
              backgroundColor: AppTheme.primaryColor,
            ),
            
            const SizedBox(height: 12),
            
            // Done button
            CustomButton(
              text: 'I have saved it',
              onPressed: () => Navigator.pop(context),
              isOutlined: true,
              backgroundColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

