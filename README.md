# Electid - Elected Official NFT Identity

A Clarity smart contract for creating verifiable NFT identities for elected officials, providing proof of legitimacy and transparency in governance.

## Overview

Electid enables the creation of non-fungible tokens that represent elected official identities. Each NFT contains verified information about an official's position, jurisdiction, and term of service, creating an immutable record of their legitimacy.

## Features

- **Official Identity NFTs**: Mint unique tokens for elected officials
- **Verification System**: Authorized issuers can verify official status
- **Term Management**: Track active, future, and expired terms
- **Transfer Restrictions**: Officials cannot transfer their identity during active terms
- **Multi-Jurisdiction Support**: Federal, state, county, city, and municipal levels
- **Position Types**: Presidents, senators, representatives, governors, mayors, commissioners, judges, sheriffs
- **Emergency Controls**: Authorized issuers can handle emergency transfers

## Contract Functions

### Administrative Functions

#### `initialize-contract`
```clarity
(initialize-contract (uri (string-ascii 256)))
```
Initialize the contract with a base URI. Only callable by contract owner.

#### `add-authorized-issuer`
```clarity
(add-authorized-issuer (issuer principal))
```
Add a new authorized issuer who can mint and verify official NFTs.

#### `remove-authorized-issuer`
```clarity
(remove-authorized-issuer (issuer principal))
```
Remove an authorized issuer's permissions.

### Minting Functions

#### `mint-official-nft`
```clarity
(mint-official-nft 
  (recipient principal)
  (name (string-ascii 64))
  (position (string-ascii 64))
  (jurisdiction (string-ascii 64))
  (term-start uint)
  (term-end uint)
  (image-uri (optional (string-ascii 256))))
```
Mint a new official NFT. Only authorized issuers can call this function.

### Verification Functions

#### `verify-official`
```clarity
(verify-official (token-id uint))
```
Mark an official as verified. Only authorized issuers can verify.

#### `revoke-verification`
```clarity
(revoke-verification (token-id uint))
```
Remove verification status from an official.

### Transfer Functions

#### `transfer`
```clarity
(transfer (token-id uint) (sender principal) (recipient principal))
```
Transfer an NFT. Only allowed after the official's term has expired.

#### `emergency-transfer`
```clarity
(emergency-transfer (token-id uint) (new-owner principal))
```
Emergency transfer by authorized issuers for special circumstances.

### Query Functions

#### `get-official-metadata`
```clarity
(get-official-metadata (token-id uint))
```
Get complete metadata for an official including name, position, jurisdiction, and term dates.

#### `is-verified-official`
```clarity
(is-verified-official (token-id uint))
```
Check if an official is verified.

#### `is-term-active`
```clarity
(is-term-active (token-id uint))
```
Check if an official's term is currently active.

#### `get-term-status`
```clarity
(get-term-status (token-id uint))
```
Get term status: "FUTURE", "ACTIVE", "EXPIRED", or "NOT_FOUND".

#### `get-officials-by-jurisdiction`
```clarity
(get-officials-by-jurisdiction (jurisdiction (string-ascii 64)))
```
Get list of token IDs for officials in a specific jurisdiction.

## Usage Example

1. **Initialize the contract**:
```clarity
(contract-call? .Electid initialize-contract "https://api.electid.gov/metadata/")
```

2. **Add an authorized issuer**:
```clarity
(contract-call? .Electid add-authorized-issuer 'SP1234567890ABCDEF)
```

3. **Mint an official NFT**:
```clarity
(contract-call? .Electid mint-official-nft 
  'SP0987654321FEDCBA 
  "John Smith" 
  "MAYOR" 
  "CITY" 
  u1000000 
  u1500000 
  (some "https://images.electid.gov/mayor-smith.png"))
```

4. **Verify the official**:
```clarity
(contract-call? .Electid verify-official u1)
```

5. **Check if term is active**:
```clarity
(contract-call? .Electid is-term-active u1)
```

## Supported Jurisdictions

- FEDERAL
- STATE  
- COUNTY
- CITY
- MUNICIPAL

## Supported Position Types

- PRESIDENT
- SENATOR
- REPRESENTATIVE
- GOVERNOR
- MAYOR
- COMMISSIONER
- JUDGE
- SHERIFF

## Error Codes

- `u100`: Owner only function
- `u101`: Not token owner
- `u102`: Not authorized issuer
- `u103`: Token already exists
- `u104`: Token not found
- `u105`: Invalid term dates
- `u106`: Term expired
- `u107`: Transfer restricted during active term
- `u108`: Invalid jurisdiction code

## Security Features

- Only authorized issuers can mint official NFTs
- Officials cannot transfer their identity during active terms
- Emergency transfer capability for authorized issuers
- Verification system prevents impersonation
- Term validation ensures proper governance periods

## Development

This contract uses Clarinet for development and testing. Ensure you have Clarinet installed and run tests with:

```bash
clarinet test
```

## License

This project is open source and available under the MIT License.
