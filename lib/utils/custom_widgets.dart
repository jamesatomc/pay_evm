import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isFullWidth;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isFullWidth = true,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget button;

    final theme = Theme.of(context);
    final foreground = textColor ?? (isOutlined ? theme.colorScheme.primary : Colors.white);

    if (isOutlined) {
      button = OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)))
            : (icon != null ? Icon(icon, color: foreground) : const SizedBox.shrink()),
        label: Text(text, style: TextStyle(color: foreground)),
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: (backgroundColor ?? theme.colorScheme.primary).withOpacity(0.14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium)),
        ),
      );
    } else {
      button = ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : (icon != null ? Icon(icon, color: foreground) : const SizedBox.shrink()),
        label: Text(text, style: TextStyle(color: foreground)),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? theme.colorScheme.primary,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium)),
          elevation: onPressed != null ? 6 : 0,
          shadowColor: theme.colorScheme.primary.withOpacity(0.14),
        ),
      );
    }

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

class BalanceCard extends StatelessWidget {
  final String totalBalance;
  final String currency;
  final String? walletName;
  final String? walletAddress;
  final String? networkName;
  final IconData? networkIcon;
  final Color? networkColor;
  final VoidCallback? onCopyAddress;
  final VoidCallback? onNetworkTap;

  const BalanceCard({
    super.key,
    required this.totalBalance,
    this.currency = 'USD',
    this.walletName,
    this.walletAddress,
    this.networkName,
    this.networkIcon,
    this.networkColor,
    this.onCopyAddress,
    this.onNetworkTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 350;
        final isMedium = constraints.maxWidth < 500;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: AppTheme.elevatedShadow,
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.06)),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              isSmall ? AppTheme.spacingM : AppTheme.spacingL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with network and wallet info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Balance', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color)),
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (networkName != null) ...[
                            GestureDetector(
                              onTap: onNetworkTap,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmall
                                      ? AppTheme.spacingXS
                                      : AppTheme.spacingS,
                                  vertical: AppTheme.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.06)
                                      : Theme.of(context).cardColor.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.06)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (networkIcon != null)
                                      Icon(
                                        networkIcon,
                                        size: isSmall ? 10 : 12,
                                        color: Colors.white,
                                      ),
                                    SizedBox(
                                      width: isSmall ? 2 : AppTheme.spacingXS,
                                    ),
                                    Text(
                                      networkName!,
                                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: isSmall ? 9 : 11, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: isSmall ? 4 : AppTheme.spacingS),
                          ],
                          if (walletName != null)
                            Text(walletName!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: isSmall ? AppTheme.spacingS : AppTheme.spacingL,
                ),

                // Balance amount
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(currency == 'USD' ? '\$$totalBalance' : '$totalBalance $currency',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: isSmall ? 22 : (isMedium ? 28 : 34), fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
                ),

                SizedBox(
                  height: isSmall ? AppTheme.spacingS : AppTheme.spacingM,
                ),

                // Wallet address
                if (walletAddress != null)
                  GestureDetector(
                    onTap: onCopyAddress,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall
                            ? AppTheme.spacingS
                            : AppTheme.spacingM,
                        vertical: AppTheme.spacingS,
                      ),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Theme.of(context).cardColor.withOpacity(0.6), borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}',
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontFamily: 'monospace', fontSize: isSmall ? 12 : 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: isSmall ? 4 : AppTheme.spacingS),
                          const Icon(Icons.copy, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AssetListItem extends StatelessWidget {
  final String name;
  final String symbol;
  final double amount;
  final double usdValue;
  final IconData? icon;
  final String? iconUrl;
  final VoidCallback? onTap;

  const AssetListItem({
    super.key,
    required this.name,
    required this.symbol,
    required this.amount,
    required this.usdValue,
    this.icon,
    this.iconUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(AppTheme.spacingM),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
          ),
          child: iconUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusSmall,
                  ),
                  child: Image.network(
                    iconUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      icon ?? Icons.currency_bitcoin,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              : Icon(
                  icon ?? Icons.currency_bitcoin,
                  color: AppTheme.primaryColor,
                ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          '${amount.toStringAsFixed(4)} $symbol',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${usdValue.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              '+0.00%', // You can add percentage change here
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bgColor = backgroundColor ?? theme.cardColor;
    final Color effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final Color textColor = iconColor ?? theme.colorScheme.onSurface;

    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : AppTheme.cardShadow,
          border: Border.all(color: theme.dividerColor.withOpacity(isDark ? 0.14 : 0.06), width: 1),
        ),
        child: Material(
          color: AppTheme.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: effectiveIconColor, size: 24),
                const SizedBox(height: AppTheme.spacingXS),
                Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(
                  AppTheme.borderRadiusXLarge,
                ),
              ),
              child: Icon(icon, size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              CustomButton(
                text: buttonText!,
                onPressed: onButtonPressed,
                isFullWidth: false,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
