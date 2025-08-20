import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import '../services/transaction_service.dart';
import '../services/network_service.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';
import 'TransactionDetailScreen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final WalletModel wallet;

  const TransactionHistoryScreen({
    super.key,
    required this.wallet,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final TransactionService _transactionService = TransactionService();
  final NetworkService _networkService = NetworkService();
  
  List<TransactionModel> _transactions = [];
  NetworkModel? _currentNetwork;
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeAndLoadTransactions();
  }

  Future<void> _initializeAndLoadTransactions() async {
    await _transactionService.loadCacheFromStorage();
    await _loadCurrentNetwork();
    await _loadTransactions();
  }

  Future<void> _loadCurrentNetwork() async {
    try {
      _currentNetwork = await _networkService.getActiveNetwork();
    } catch (e) {
      print('Error loading current network: $e');
    }
  }

  Future<void> _loadTransactions({bool forceRefresh = false}) async {
    if (_currentNetwork == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transactions = await _transactionService.getTransactionHistory(
        walletAddress: widget.wallet.address,
        networkId: _currentNetwork!.id,
        limit: 100,
        forceRefresh: forceRefresh,
      );

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load transactions: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading transactions: $e');
    }
  }

  Future<void> _refreshTransactions() async {
    await _loadTransactions(forceRefresh: true);
  }

  void _showTransactionDetails(TransactionModel transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          transaction: transaction,
          walletAddress: widget.wallet.address,
        ),
      ),
    );
  }

  void _copyTransactionHash(String hash) {
    Clipboard.setData(ClipboardData(text: hash));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction hash copied to clipboard'),
        backgroundColor: AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: AppTheme.surfaceColor,
          appBar: AppBar(
            title: const Text('Transaction History'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: AppTheme.textPrimary),
                onPressed: _isLoading ? null : _refreshTransactions,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: AppTheme.spacingS),
            ],
          ),
          body: Column(
            children: [
              // Wallet and Network Info
              Container(
                margin: const EdgeInsets.all(AppTheme.spacingM),
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: AppTheme.primaryColor,
                          size: isSmallScreen ? 16 : 20,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Flexible(
                          child: Text(
                            widget.wallet.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Address: ${widget.wallet.address}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                    if (_currentNetwork != null) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Network: ${_currentNetwork!.name}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Transactions List
              Expanded(
                child: _buildTransactionsList(isSmallScreen),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsList(bool isSmallScreen) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Error Loading Transactions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: _refreshTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const EmptyState(
        title: 'No Transactions Yet',
        subtitle: 'Your transaction history will appear here once you start sending or receiving crypto',
        icon: Icons.receipt_long_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionItem(transaction, isSmallScreen);
        },
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction, bool isSmallScreen) {
    final isIncoming = transaction.isIncoming(widget.wallet.address);
    final isSuccessful = transaction.status.isSuccessful;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spacingM),
        leading: Container(
          width: isSmallScreen ? 40 : 48,
          height: isSmallScreen ? 40 : 48,
          decoration: BoxDecoration(
            color: _getTransactionColor(transaction, isIncoming).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
          ),
          child: Icon(
            _getTransactionIcon(transaction, isIncoming),
            color: _getTransactionColor(transaction, isIncoming),
            size: isSmallScreen ? 20 : 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _getTransactionTitle(transaction, isIncoming),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
            Text(
              transaction.getFormattedAmount(widget.wallet.address),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSuccessful
                    ? (isIncoming ? AppTheme.secondaryColor : AppTheme.textPrimary)
                    : AppTheme.errorColor,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacingXS),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getTransactionSubtitle(transaction, isIncoming),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (transaction.usdValue != null)
                  Text(
                    transaction.getFormattedUsdValue(widget.wallet.address) ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction.status),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  ),
                  child: Text(
                    transaction.status.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ThemeData.estimateBrightnessForColor(
                                  _getStatusColor(transaction.status)) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(transaction.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.copy,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              onPressed: () => _copyTransactionHash(transaction.hash),
              tooltip: 'Copy transaction hash',
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  String _getTransactionTitle(TransactionModel transaction, bool isIncoming) {
    if (transaction.status == TransactionStatus.failed) {
      return 'Failed Transaction';
    }
    
    switch (transaction.type) {
      case TransactionType.transfer:
        return isIncoming ? 'Received' : 'Sent';
      case TransactionType.tokenTransfer:
        return isIncoming ? 'Received Token' : 'Sent Token';
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

  String _getTransactionSubtitle(TransactionModel transaction, bool isIncoming) {
    final address = isIncoming ? transaction.from : transaction.to;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  IconData _getTransactionIcon(TransactionModel transaction, bool isIncoming) {
    if (transaction.status == TransactionStatus.failed) {
      return Icons.error_outline;
    }
    
    switch (transaction.type) {
      case TransactionType.transfer:
      case TransactionType.tokenTransfer:
        return isIncoming ? Icons.arrow_downward : Icons.arrow_upward;
      case TransactionType.contractInteraction:
        return Icons.code;
      case TransactionType.approval:
        return Icons.check_circle_outline;
      case TransactionType.swap:
        return Icons.swap_horiz;
      case TransactionType.stake:
        return Icons.lock_outline;
      case TransactionType.unstake:
        return Icons.lock_open_outlined;
    }
  }

  Color _getTransactionColor(TransactionModel transaction, bool isIncoming) {
    if (transaction.status == TransactionStatus.failed) {
      return AppTheme.errorColor;
    }
    
    switch (transaction.type) {
      case TransactionType.transfer:
      case TransactionType.tokenTransfer:
        return isIncoming ? AppTheme.secondaryColor : AppTheme.primaryColor;
      case TransactionType.contractInteraction:
        return Colors.purple;
      case TransactionType.approval:
  return AppTheme.primaryColor;
      case TransactionType.swap:
        return Colors.orange;
      case TransactionType.stake:
        return Colors.green;
      case TransactionType.unstake:
        return Colors.amber;
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.confirmed:
        return AppTheme.secondaryColor;
      case TransactionStatus.failed:
        return AppTheme.errorColor;
      case TransactionStatus.cancelled:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      // Today
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
