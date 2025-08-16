class WalletModel {
  final String address;
  final String privateKey;
  final String mnemonic;
  final String name;
  final DateTime createdAt;

  WalletModel({
    required this.address,
    required this.privateKey,
    required this.mnemonic,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'privateKey': privateKey,
      'mnemonic': mnemonic,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      address: json['address'],
      privateKey: json['privateKey'],
      mnemonic: json['mnemonic'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class TokenModel {
  final String name;
  final String symbol;
  final String contractAddress;
  final int decimals;
  final double balance;
  final double usdValue;

  TokenModel({
    required this.name,
    required this.symbol,
    required this.contractAddress,
    required this.decimals,
    required this.balance,
    required this.usdValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'symbol': symbol,
      'contractAddress': contractAddress,
      'decimals': decimals,
      'balance': balance,
      'usdValue': usdValue,
    };
  }

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      name: json['name'],
      symbol: json['symbol'],
      contractAddress: json['contractAddress'],
      decimals: json['decimals'],
      balance: json['balance'].toDouble(),
      usdValue: json['usdValue'].toDouble(),
    );
  }
}
