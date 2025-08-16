import 'package:flutter/material.dart';
import 'package:pay_evm/screenpage/WalletScreen.dart';


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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black12,
        ),
      ),
      home: const WalletScreen(),
    );
  }
}


