# TicketChain

A decentralized concert ticket resale marketplace built on Stacks blockchain using Clarity smart contracts.

## Overview

TicketChain is a secure and transparent platform that enables concert ticket resale through blockchain technology. It supports multiple pricing models, including fixed-price sales, auctions, and dynamic pricing, while ensuring fair transactions between sellers and buyers.

## Features

- **Multiple Sale Types**
  - Fixed-price listings
  - Auction-based sales
  - Dynamic pricing support

- **Secure Transactions**
  - Smart contract-based purchases
  - Automated refund processing
  - Protected ticket transfers

- **Section Management**
  - Support for multiple seating sections
  - Section-specific availability tracking
  - Flexible pricing per section

- **Listing Controls**
  - Time-based listing expiration
  - Seller cancellation options
  - Admin-controlled availability updates

## Smart Contract Functions

### For Sellers

- `create-listing`: Create a new ticket listing with customizable parameters
- `close-listing`: End an active listing after the specified block height
- `cancel-listing`: Cancel a listing and process refunds

### For Buyers

- `purchase-ticket`: Purchase tickets from an active listing
- `claim-refund`: Claim refunds for eligible purchases
- `get-purchase`: View purchase details

### Administrative

- `update-availability`: Update section availability
- `get-listing`: View listing details

## Error Handling

The contract includes comprehensive error handling for various scenarios:

- Unauthorized actions
- Invalid pricing or section selections
- Listing state conflicts
- Insufficient funds
- Refund processing issues

## Technical Details

### Contract Constants

- Sale types: fixed-price, auction, dynamic-pricing
- Maximum sections: 10
- Maximum available sections: 5
- Maximum description length: 256 characters

### Data Structures

- Listings map: Stores all concert ticket listings
- Purchases map: Tracks buyer purchases and payments
- Sale types: Defines supported sale mechanisms

## Getting Started

To interact with the TicketChain contract:

1. Deploy the contract to the Stacks blockchain
2. Initialize the contract with `(contract-call? .ticketchain Component)`
3. Create listings using the `create-listing` function
4. Manage purchases and refunds through the provided public functions

## Security Considerations

- Only the contract owner can update section availability
- Listings have built-in expiration mechanics
- Refunds are processed automatically during cancellations
- Purchase validation prevents invalid section selection

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
