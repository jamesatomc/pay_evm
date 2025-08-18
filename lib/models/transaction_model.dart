class TransactionModel {
  final String hash;
  final String from;
  final String to;
  final double amount;
  final String symbol;
  final double? usdValue;
  final int timestamp;
  final TransactionStatus status;
  final TransactionType type;
  final String networkId;
  final String? tokenAddress;
  final double gasUsed;
  final double gasPrice;
  final double gasFee;
  final int blockNumber;
  final int confirmations;
  final String? error;

  const TransactionModel({
    required this.hash,
    required this.from,
    required this.to,
    required this.amount,
    required this.symbol,
    this.usdValue,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.networkId,
    this.tokenAddress,
    required this.gasUsed,
    required this.gasPrice,
    required this.gasFee,
    required this.blockNumber,
    required this.confirmations,
    this.error,
  });

  // Get transaction date
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  // Check if transaction is incoming
  bool isIncoming(String walletAddress) {
    return to.toLowerCase() == walletAddress.toLowerCase();
  }

  // Check if transaction is outgoing
  bool isOutgoing(String walletAddress) {
    return from.toLowerCase() == walletAddress.toLowerCase();
  }

  // Check if transaction is native token transfer
  bool get isNativeTransfer => tokenAddress == null || tokenAddress!.isEmpty;

  // Check if transaction is token transfer
  bool get isTokenTransfer => tokenAddress != null && tokenAddress!.isNotEmpty;

  // Get formatted amount with sign for display
  String getFormattedAmount(String walletAddress) {
    final isIncoming = this.isIncoming(walletAddress);
    final sign = isIncoming ? '+' : '-';
    return '$sign${amount.toStringAsFixed(6)} $symbol';
  }

  // Get formatted USD value with sign
  String? getFormattedUsdValue(String walletAddress) {
    if (usdValue == null) return null;
    final isIncoming = this.isIncoming(walletAddress);
    final sign = isIncoming ? '+' : '-';
    return '$sign\$${usdValue!.toStringAsFixed(2)}';
  }

  // Create from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      hash: json['hash'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      symbol: json['symbol'] ?? '',
      usdValue: json['usdValue'] != null ? (json['usdValue'] as num).toDouble() : null,
      timestamp: json['timestamp'] ?? 0,
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString() == 'TransactionStatus.${json['status']}',
        orElse: () => TransactionStatus.pending,
      ),
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == 'TransactionType.${json['type']}',
        orElse: () => TransactionType.transfer,
      ),
      networkId: json['networkId'] ?? '',
      tokenAddress: json['tokenAddress'],
      gasUsed: (json['gasUsed'] ?? 0.0).toDouble(),
      gasPrice: (json['gasPrice'] ?? 0.0).toDouble(),
      gasFee: (json['gasFee'] ?? 0.0).toDouble(),
      blockNumber: json['blockNumber'] ?? 0,
      confirmations: json['confirmations'] ?? 0,
      error: json['error'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'from': from,
      'to': to,
      'amount': amount,
      'symbol': symbol,
      'usdValue': usdValue,
      'timestamp': timestamp,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'networkId': networkId,
      'tokenAddress': tokenAddress,
      'gasUsed': gasUsed,
      'gasPrice': gasPrice,
      'gasFee': gasFee,
      'blockNumber': blockNumber,
      'confirmations': confirmations,
      'error': error,
    };
  }

  // Create a copy with updated values
  TransactionModel copyWith({
    String? hash,
    String? from,
    String? to,
    double? amount,
    String? symbol,
    double? usdValue,
    int? timestamp,
    TransactionStatus? status,
    TransactionType? type,
    String? networkId,
    String? tokenAddress,
    double? gasUsed,
    double? gasPrice,
    double? gasFee,
    int? blockNumber,
    int? confirmations,
    String? error,
  }) {
    return TransactionModel(
      hash: hash ?? this.hash,
      from: from ?? this.from,
      to: to ?? this.to,
      amount: amount ?? this.amount,
      symbol: symbol ?? this.symbol,
      usdValue: usdValue ?? this.usdValue,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      networkId: networkId ?? this.networkId,
      tokenAddress: tokenAddress ?? this.tokenAddress,
      gasUsed: gasUsed ?? this.gasUsed,
      gasPrice: gasPrice ?? this.gasPrice,
      gasFee: gasFee ?? this.gasFee,
      blockNumber: blockNumber ?? this.blockNumber,
      confirmations: confirmations ?? this.confirmations,
      error: error ?? this.error,
    );
  }
}

enum TransactionStatus {
  pending,
  confirmed,
  failed,
  cancelled,
}

enum TransactionType {
  transfer,
  tokenTransfer,
  contractInteraction,
  approval,
  swap,
  stake,
  unstake,
}

// Extension to get display properties for transaction status
extension TransactionStatusExtension on TransactionStatus {
  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isCompleted {
    return this == TransactionStatus.confirmed || 
           this == TransactionStatus.failed || 
           this == TransactionStatus.cancelled;
  }

  bool get isSuccessful {
    return this == TransactionStatus.confirmed;
  }
}

// Extension to get display properties for transaction type
extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.tokenTransfer:
        return 'Token Transfer';
      case TransactionType.contractInteraction:
        return 'Contract Interaction';
      case TransactionType.approval:
        return 'Token Approval';
      case TransactionType.swap:
        return 'Swap';
      case TransactionType.stake:
        return 'Stake';
      case TransactionType.unstake:
        return 'Unstake';
    }
  }
}
