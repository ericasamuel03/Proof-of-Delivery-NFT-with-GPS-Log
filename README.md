# 📦 Proof of Delivery NFT with GPS Log

A Clarity smart contract that enables delivery companies to mint NFTs as proof of delivery, containing verified metadata including GPS location hashes, digital signatures, and timestamps.

## 🚀 Features

- **📋 NFT-based Delivery Proof**: Each delivery generates a unique NFT token
- **🌍 GPS Location Tracking**: Secure location hashes for delivery verification
- **✍️ Digital Signatures**: Capture recipient signatures on delivery
- **⏰ Timestamp Records**: Immutable delivery time tracking
- **🏢 Company Authorization**: Only authorized delivery companies can mint proofs
- **📊 Delivery Status**: Track pending, delivered, and failed deliveries
- **🔍 Verification System**: Easy verification of delivery authenticity

## 🛠️ Usage

### For Contract Owners

#### Authorize a Delivery Company
```clarity
(contract-call? .delivery-proof authorize-company 'SP1EXAMPLE...)
```

#### Revoke Company Authorization
```clarity
(contract-call? .delivery-proof revoke-company 'SP1EXAMPLE...)
```

### For Delivery Companies

#### Mint Delivery Proof NFT
```clarity
(contract-call? .delivery-proof mint-delivery-proof 
    'SP1RECIPIENT...
    "TRK123456789"
    "123 Main St, City, State 12345"
    "sha256:abc123def456...")
```

#### Confirm Successful Delivery
```clarity
(contract-call? .delivery-proof confirm-delivery 
    u1
    "John_Doe_Signature_2024"
    "sha256:final_location_hash...")
```

#### Mark Failed Delivery
```clarity
(contract-call? .delivery-proof mark-failed-delivery u1)
```

### For Recipients & Verifiers

#### Verify Delivery
```clarity
(contract-call? .delivery-proof verify-delivery 
    u1
    "TRK123456789"
    "123 Main St, City, State 12345")
```

#### Get Delivery Metadata
```clarity
(contract-call? .delivery-proof get-delivery-metadata u1)
```

#### Check Delivery Status
```clarity
(contract-call? .delivery-proof get-delivery-status u1)
```

## 📋 Contract Functions

### Public Functions
- `mint-delivery-proof` - Create new delivery proof NFT
- `confirm-delivery` - Mark delivery as completed with signature
- `mark-failed-delivery` - Mark delivery as failed
- `authorize-company` - Authorize delivery company (owner only)
- `revoke-company` - Revoke company authorization (owner only)
- `transfer` - Transfer NFT ownership

### Read-Only Functions
- `get-delivery-metadata` - Get complete delivery information
- `verify-delivery` - Verify delivery with tracking and address
- `get-delivery-status` - Get current delivery status
- `get-delivery-signature` - Get delivery signature
- `get-location-hash` - Get GPS location hash
- `get-tracking-number` - Get tracking number
- `get-delivery-company` - Get delivering company
- `is-company-authorized` - Check company authorization

## 🏗️ Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for testing

### Setup
```bash
clarinet new delivery-proof-project
cd delivery-proof-project
# Copy the contract file to contracts/
```

### Testing
```bash
clarinet test
```

### Deploy
```bash
clarinet deploy --testnet
```

## 📋 Data Structure

Each delivery proof NFT contains:
- **Tracking Number**: Unique package identifier
- **Recipient Address**: Full delivery address
- **Location Hash**: GPS coordinates hash for privacy
- **Delivery Signature**: Digital signature on delivery
- **Timestamp**: Block time when action occurred
- **Delivery Company**: Principal of delivering company
- **Status**: pending | delivered | failed

## 🔒 Security Features

- Only authorized companies can mint delivery proofs
- Companies can only modify their own deliveries
- Immutable proof once delivery is confirmed
- GPS location hashed for privacy protection
- Time-stamped with blockchain time

## 📄 License

MIT License - see LICENSE file for details.
