# Changelog

## Version 2.0.0 - Multi-Network Support

### 🎉 New Features
- **Multi-Network Support**: Switch between different blockchain networks
- **Network Selector Widget**: Easy network switching UI with network indicators
- **Testnet Support**: Full support for multiple testnets
- **Dynamic Currency Display**: Shows correct currency symbol based on selected network

### 🌐 Supported Networks

#### Mainnets
- BNB Smart Chain (BNB)
- Polygon (MATIC)  
- Avalanche C-Chain (AVAX)
- Fantom Opera (FTM)
- Ethereum Mainnet (ETH)

#### Testnets
- BNB Smart Chain Testnet (tBNB)
- Polygon Mumbai (MATIC)
- Avalanche Fuji (AVAX)
- Fantom Testnet (FTM)
- Ethereum Sepolia (ETH)

### 🎨 UI Improvements
- Network indicator in app bar
- Color-coded network types (green for mainnet, orange for testnet)
- Dynamic button labels based on selected network
- Network selector bottom sheet with organized layout

### 🔧 Technical Improvements
- NetworkService for managing blockchain networks
- Dynamic Web3Client creation based on selected network
- Improved error handling for network operations
- Better code organization and modularity

### 💡 Usage
1. Tap the network indicator in the app bar to switch networks
2. Choose from mainnet or testnet options
3. App automatically updates balance and currency display
4. Send transactions on the selected network

### ⚠️ Important Notes
- Make sure you have test tokens for testnet operations
- Some Ethereum networks require Infura API key (replace YOUR_PROJECT_ID)
- Always verify the network before sending transactions
- Testnet tokens have no real value
