# 🌐 Multi-Network Crypto Wallet

A Flutter-based cryptocurrency wallet supporting multiple blockchain networks with custom network functionality.

## ✨ Features

### 🔗 Network Support
- **Pre-configured Networks**: Support for major blockchain networks
  - BNB Smart Chain (Mainnet & Testnet)
  - Polygon (Mainnet & Mumbai Testnet)
  - Avalanche (C-Chain & Fuji Testnet)
  - Fantom (Opera & Testnet)
  - Ethereum (Mainnet & Sepolia)

- **Custom Networks**: Add your own blockchain networks
  - Custom RPC URLs
  - Custom Chain IDs
  - Custom currency symbols
  - Custom block explorers
  - Edit and delete custom networks

### 🎯 Wallet Features
- 🔐 **Secure Wallet Creation**: Generate new wallets with 12-word mnemonic
- 📥 **Wallet Import**: Import existing wallets using mnemonic phrases
- 💰 **Balance Display**: View native token balance on selected network
- 💸 **Send Transactions**: Send native tokens to any address
- 🔄 **Network Switching**: Easy network switching with visual indicators

### 🎨 User Interface
- 🌈 **Modern Design**: Clean and intuitive interface
- 🎨 **Color-coded Networks**: 
  - 🟢 Green for mainnets
  - 🟠 Orange for testnets
  - 🔵 Blue for custom networks
- 📱 **Responsive Layout**: Works on all screen sizes
- 🔄 **Network Indicator**: Shows current network in app bar

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Dart SDK
- Android Studio / VS Code

### Installation
1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`

## 📖 Usage Guide

### First Time Setup
1. **Create Wallet**: Tap "Create New Wallet" to generate a new wallet
2. **Backup Mnemonic**: Save the 12-word mnemonic phrase securely
3. **Or Import**: Use "Import Wallet" with existing mnemonic

### Network Management
1. **Switch Networks**: Tap the network indicator in the top-right corner
2. **Select Network**: Choose from predefined or custom networks
3. **Add Custom Network**: Tap the "+" button in network selector

### Adding Custom Networks
1. **Open Network Selector**: Tap network indicator
2. **Add Network**: Tap the "+" icon
3. **Fill Details**:
   - Network Name (e.g., "My Custom Chain")
   - RPC URL (e.g., "https://rpc.example.com")
   - Chain ID (e.g., 1337)
   - Currency Symbol (e.g., "CUSTOM")
   - Block Explorer URL (optional)
   - Toggle testnet if applicable
4. **Test Connection**: Use the test button to verify RPC
5. **Save Network**: Tap "Add Network"

### Editing/Deleting Custom Networks
1. **Open Network Selector**
2. **Find Custom Network** in the "Custom Networks" section
3. **Tap Menu**: Use the three-dot menu for options
4. **Edit/Delete**: Choose your desired action

## ⚠️ Important Notes

1. **Backup Your Mnemonic**: Always backup your 12-word mnemonic phrase
2. **Test Networks First**: Use testnets before mainnet operations
3. **Verify Addresses**: Double-check recipient addresses before sending
4. **Custom Networks**: Verify RPC URLs and chain IDs before adding

## 🔒 Security Features

- **Secure Storage**: Private keys encrypted using Flutter Secure Storage
- **Mnemonic Backup**: 12-word backup phrases for wallet recovery
- **Network Validation**: RPC connection testing before adding networks
- **Transaction Confirmation**: Clear transaction details before sending

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
