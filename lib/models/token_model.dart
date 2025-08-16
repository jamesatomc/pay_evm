class CustomTokenModel {
  final String contractAddress;
  final String name;
  final String symbol;
  final int decimals;
  final String? iconUrl;
  final bool isNative;
  final String networkId;
  final double balance;
  final double? price; // USD price per token
  final bool isEnabled;

  const CustomTokenModel({
    required this.contractAddress,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.iconUrl,
    this.isNative = false,
    required this.networkId,
    this.balance = 0.0,
    this.price,
    this.isEnabled = true,
  });

  // Calculate USD value
  double get usdValue => balance * (price ?? 0.0);

  // Create a copy with updated values
  CustomTokenModel copyWith({
    String? contractAddress,
    String? name,
    String? symbol,
    int? decimals,
    String? iconUrl,
    bool? isNative,
    String? networkId,
    double? balance,
    double? price,
    bool? isEnabled,
  }) {
    return CustomTokenModel(
      contractAddress: contractAddress ?? this.contractAddress,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      decimals: decimals ?? this.decimals,
      iconUrl: iconUrl ?? this.iconUrl,
      isNative: isNative ?? this.isNative,
      networkId: networkId ?? this.networkId,
      balance: balance ?? this.balance,
      price: price ?? this.price,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toJson() {
    return {
      'contractAddress': contractAddress,
      'name': name,
      'symbol': symbol,
      'decimals': decimals,
      'iconUrl': iconUrl,
      'isNative': isNative,
      'networkId': networkId,
      'balance': balance,
      'price': price,
      'isEnabled': isEnabled,
    };
  }

  // Create from Map
  factory CustomTokenModel.fromJson(Map<String, dynamic> json) {
    return CustomTokenModel(
      contractAddress: json['contractAddress'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      decimals: json['decimals'] ?? 18,
      iconUrl: json['iconUrl'],
      isNative: json['isNative'] ?? false,
      networkId: json['networkId'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      price: json['price']?.toDouble(),
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  // Create native token (ETH, BNB, etc.)
  factory CustomTokenModel.native({
    required String name,
    required String symbol,
    required String networkId,
    double balance = 0.0,
    double? price,
    String? iconUrl,
  }) {
    return CustomTokenModel(
      contractAddress: '0x0000000000000000000000000000000000000000', // Native token address
      name: name,
      symbol: symbol,
      decimals: 18,
      iconUrl: iconUrl,
      isNative: true,
      networkId: networkId,
      balance: balance,
      price: price,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomTokenModel &&
        other.contractAddress.toLowerCase() == contractAddress.toLowerCase() &&
        other.networkId == networkId;
  }

  @override
  int get hashCode => contractAddress.toLowerCase().hashCode ^ networkId.hashCode;

  @override
  String toString() {
    return 'CustomTokenModel(name: $name, symbol: $symbol, address: $contractAddress, network: $networkId, balance: $balance)';
  }
}
