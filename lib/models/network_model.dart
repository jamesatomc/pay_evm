class NetworkModel {
  final String id;
  final String name;
  final String rpcUrl;
  final int chainId;
  final String currencySymbol;
  final String? blockExplorerUrl;
  final bool isTestnet;
  final bool isCustom;
  final String iconPath;

  const NetworkModel({
    required this.id,
    required this.name,
    required this.rpcUrl,
    required this.chainId,
    required this.currencySymbol,
    this.blockExplorerUrl,
    this.isTestnet = false,
    this.isCustom = false,
    required this.iconPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rpcUrl': rpcUrl,
      'chainId': chainId,
      'currencySymbol': currencySymbol,
      'blockExplorerUrl': blockExplorerUrl,
      'isTestnet': isTestnet,
      'isCustom': isCustom,
      'iconPath': iconPath,
    };
  }

  factory NetworkModel.fromJson(Map<String, dynamic> json) {
    return NetworkModel(
      id: json['id'],
      name: json['name'],
      rpcUrl: json['rpcUrl'],
      chainId: json['chainId'],
      currencySymbol: json['currencySymbol'],
      blockExplorerUrl: json['blockExplorerUrl'],
      isTestnet: json['isTestnet'] ?? false,
      isCustom: json['isCustom'] ?? false,
      iconPath: json['iconPath'],
    );
  }

  NetworkModel copyWith({
    String? id,
    String? name,
    String? rpcUrl,
    int? chainId,
    String? currencySymbol,
    String? blockExplorerUrl,
    bool? isTestnet,
    bool? isCustom,
    String? iconPath,
  }) {
    return NetworkModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rpcUrl: rpcUrl ?? this.rpcUrl,
      chainId: chainId ?? this.chainId,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      blockExplorerUrl: blockExplorerUrl ?? this.blockExplorerUrl,
      isTestnet: isTestnet ?? this.isTestnet,
      isCustom: isCustom ?? this.isCustom,
      iconPath: iconPath ?? this.iconPath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NetworkModel(id: $id, name: $name, chainId: $chainId)';
  }
}
