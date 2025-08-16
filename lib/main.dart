import 'package:flutter/material.dart';
import 'package:pay_evm/screenpage/WalletScreen.dart';
import 'package:pay_evm/utils/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kanari Wallet',
      theme: AppTheme.lightTheme,
      home: const WalletScreen(),
    );
  }
}


