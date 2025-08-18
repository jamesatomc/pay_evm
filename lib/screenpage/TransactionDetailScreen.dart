import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction_model.dart';
import '../models/network_model.dart';
import '../services/network_service.dart';
import '../services/transaction_service.dart';
import '../utils/app_theme.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  final String walletAddress;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.walletAddress,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final NetworkService _networkService = NetworkService();
  NetworkModel? _network;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
  }

  Future<void> _loadNetwork() async {
    try {
      final network = await _networkService.getNetworkById(widget.transaction.networkId);
      setState(() {
        _network = network;
      });
    } catch (e) {
      print('Error loading network: $e');
    }
  }

  Future<void> _openInExplorer() async {
    if (_network?.blockExplorerUrl == null) {
      _showSnackBar('Block explorer not available for this network');
      return;
    }

    final url = '${_network!.blockExplorerUrl}/tx/${widget.transaction.hash}';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Fallback: copy URL to clipboard
        Clipboard.setData(ClipboardData(text: url));
        _showSnackBar('Explorer URL copied to clipboard');
      }
    } catch (e) {
      // Fallback: copy URL to clipboard
      Clipboard.setData(ClipboardData(text: url));
      _showSnackBar('Explorer URL copied to clipboard');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
      ),
    );
  }

  Future<void> _refreshTransactionStatus() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      // Import transaction service
      final transactionService = TransactionService();
      final updatedTx = await transactionService.refreshTransactionStatus(widget.transaction);
      
      if (updatedTx != null && mounted) {
        // Update the transaction and trigger a rebuild
        // Note: In a real app, you'd pass this back to the parent or use state management
        _showSnackBar('Transaction status updated');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to refresh status: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        final isIncoming = widget.transaction.isIncoming(widget.walletAddress);
        final isSuccessful = widget.transaction.status.isSuccessful;
        
        return Scaffold(
          backgroundColor: AppTheme.surfaceColor,
          appBar: AppBar(
            title: const Text('Transaction Details'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (widget.transaction.status == TransactionStatus.pending)
                IconButton(
                  icon: _isRefreshing 
                      ? SizedBox(
                          width: isSmallScreen ? 16 : 20,
                          height: isSmallScreen ? 16 : 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
                          ),
                        )
                      : Icon(Icons.refresh, color: AppTheme.textPrimary),
                  onPressed: _isRefreshing ? null : _refreshTransactionStatus,
                  tooltip: 'Refresh Status',
                ),
              if (_network?.blockExplorerUrl != null)
                IconButton(
                  icon: Icon(Icons.open_in_new, color: AppTheme.textPrimary),
                  onPressed: _openInExplorer,
                  tooltip: 'View in Explorer',
                ),
              const SizedBox(width: AppTheme.spacingS),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Header
                _buildStatusHeader(isIncoming, isSuccessful, isSmallScreen),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Amount Section
                _buildAmountSection(isIncoming, isSmallScreen),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Transaction Details
                _buildDetailsCard(isSmallScreen),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Gas Information
                _buildGasInfoCard(isSmallScreen),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Actions
                _buildActions(isSmallScreen),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(bool isIncoming, bool isSuccessful, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
        children: [
          // Status Icon
          Container(
            width: isSmallScreen ? 60 : 80,
            height: isSmallScreen ? 60 : 80,
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(isIncoming),
              size: isSmallScreen ? 30 : 40,
              color: _getStatusColor(),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Transaction Type
          Text(
            _getTransactionTitle(isIncoming),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontSize: isSmallScreen ? 18 : 24,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingS),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Text(
              widget.transaction.status.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ThemeData.estimateBrightnessForColor(
                              _getStatusColor()) ==
                          Brightness.dark
                      ? Colors.white
                      : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingS),
          
          // Date
          Text(
            _formatDateTime(widget.transaction.date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(bool isIncoming, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
        children: [
          Text(
            'Amount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingS),
          
          Text(
            widget.transaction.getFormattedAmount(widget.walletAddress),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.transaction.status.isSuccessful
                  ? (isIncoming ? AppTheme.secondaryColor : AppTheme.textPrimary)
                  : AppTheme.errorColor,
              fontSize: isSmallScreen ? 20 : 24,
            ),
          ),
          
          if (widget.transaction.usdValue != null) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              widget.transaction.getFormattedUsdValue(widget.walletAddress) ?? '',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
          Text(
            'Transaction Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          _buildDetailRow('Transaction Hash', widget.transaction.hash, true, isSmallScreen),
          _buildDetailRow('From', widget.transaction.from, true, isSmallScreen),
          _buildDetailRow('To', widget.transaction.to, true, isSmallScreen),
          
          if (widget.transaction.blockNumber > 0)
            _buildDetailRow('Block Number', widget.transaction.blockNumber.toString(), false, isSmallScreen),
          
          if (widget.transaction.confirmations > 0)
            _buildDetailRow('Confirmations', widget.transaction.confirmations.toString(), false, isSmallScreen)
          else if (widget.transaction.status == TransactionStatus.pending)
            _buildDetailRow('Confirmations', 'Pending...', false, isSmallScreen)
          else
            _buildDetailRow('Confirmations', 'Unknown', false, isSmallScreen),
          
          if (_network != null)
            _buildDetailRow('Network', _network!.name, false, isSmallScreen),
          
          if (widget.transaction.tokenAddress != null && widget.transaction.tokenAddress!.isNotEmpty)
            _buildDetailRow('Token Contract', widget.transaction.tokenAddress!, true, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildGasInfoCard(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
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
          Text(
            'Gas Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          _buildDetailRow('Gas Used', widget.transaction.gasUsed > 0 
              ? widget.transaction.gasUsed.toStringAsFixed(0) 
              : 'Pending...', false, isSmallScreen),
          _buildDetailRow('Gas Price', widget.transaction.gasPrice > 0 
              ? '${widget.transaction.gasPrice.toStringAsFixed(2)} Gwei' 
              : 'Unknown', false, isSmallScreen),
          _buildDetailRow('Transaction Fee', widget.transaction.gasFee > 0 
              ? '${widget.transaction.gasFee.toStringAsFixed(6)} ${widget.transaction.symbol}' 
              : 'Calculating...', false, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [bool copyable = false, bool isSmallScreen = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontFamily: copyable ? 'monospace' : null,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: AppTheme.spacingS),
                  GestureDetector(
                    onTap: () => _copyToClipboard(value, label),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isSmallScreen) {
    return Column(
      children: [
        if (_network?.blockExplorerUrl != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInExplorer,
                icon: const Icon(Icons.open_in_new),
                label: const Text('View in Block Explorer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                ),
              ),
            ),        const SizedBox(height: AppTheme.spacingM),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _copyToClipboard(widget.transaction.hash, 'Transaction hash'),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Transaction Hash'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getTransactionTitle(bool isIncoming) {
    if (widget.transaction.status == TransactionStatus.failed) {
      return 'Failed Transaction';
    }
    
    switch (widget.transaction.type) {
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

  IconData _getStatusIcon(bool isIncoming) {
    if (widget.transaction.status == TransactionStatus.failed) {
      return Icons.error_outline;
    }
    
    switch (widget.transaction.type) {
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

  Color _getStatusColor() {
    if (widget.transaction.status == TransactionStatus.failed) {
      return AppTheme.errorColor;
    }
    
    switch (widget.transaction.status) {
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

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
