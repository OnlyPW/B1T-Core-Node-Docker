# B1T Core Node - RPC API Documentation

This document provides comprehensive documentation for the B1T Core Node RPC (Remote Procedure Call) API.

## Table of Contents

- [Authentication](#authentication)
- [Request Format](#request-format)
- [Response Format](#response-format)
- [Error Handling](#error-handling)
- [API Methods](#api-methods)
  - [Blockchain Information](#blockchain-information)
  - [Network Information](#network-information)
  - [Block Operations](#block-operations)
  - [Transaction Operations](#transaction-operations)
  - [Wallet Operations](#wallet-operations)
  - [Mining Operations](#mining-operations)
  - [Utility Methods](#utility-methods)
- [Examples](#examples)
- [Rate Limiting](#rate-limiting)
- [Security Considerations](#security-considerations)

## Authentication

The B1T Core Node RPC API uses HTTP Basic Authentication. You need to provide the username and password configured in your `.env` file.

**Default Credentials:**
- Username: `b1tuser`
- Password: `b1tpassword` (change this in production!)

**Configuration:**
```env
RPC_USER=your_username
RPC_PASSWORD=your_secure_password
```

## Request Format

All RPC requests use HTTP POST with JSON-RPC 1.0 format:

```json
{
  "jsonrpc": "1.0",
  "id": "unique_request_id",
  "method": "method_name",
  "params": ["param1", "param2"]
}
```

**Headers:**
```
Content-Type: application/json
Authorization: Basic <base64(username:password)>
```

## Response Format

**Success Response:**
```json
{
  "result": "method_result",
  "error": null,
  "id": "unique_request_id"
}
```

**Error Response:**
```json
{
  "result": null,
  "error": {
    "code": -32601,
    "message": "Method not found"
  },
  "id": "unique_request_id"
}
```

## Error Handling

### Common Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Invalid JSON-RPC |
| -32601 | Method not found | Method doesn't exist |
| -32602 | Invalid params | Invalid parameters |
| -32603 | Internal error | Internal JSON-RPC error |
| -1 | Miscellaneous error | General application error |
| -3 | Invalid amount | Invalid amount specified |
| -4 | Insufficient funds | Not enough funds |
| -5 | Invalid address | Invalid B1T address |
| -8 | Invalid parameter | Invalid parameter value |

## API Methods

### Blockchain Information

#### `getblockchaininfo`
Returns comprehensive information about the blockchain.

**Parameters:** None

**Response:**
```json
{
  "chain": "main",
  "blocks": 12345,
  "headers": 12345,
  "bestblockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
  "difficulty": 1.0,
  "mediantime": 1640995200,
  "verificationprogress": 0.9999,
  "chainwork": "0000000000000000000000000000000000000000000000000000000100010001",
  "pruned": false,
  "softforks": {},
  "warnings": ""
}
```

#### `getblockcount`
Returns the current block height.

**Parameters:** None

**Response:** `12345` (integer)

#### `getbestblockhash`
Returns the hash of the best (tip) block.

**Parameters:** None

**Response:** `"000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"`

#### `getdifficulty`
Returns the current mining difficulty.

**Parameters:** None

**Response:** `1.0` (number)

### Network Information

#### `getnetworkinfo`
Returns network-related information.

**Parameters:** None

**Response:**
```json
{
  "version": 210000,
  "subversion": "/B1T Core:2.1.0/",
  "protocolversion": 70015,
  "localservices": "0000000000000409",
  "localrelay": true,
  "timeoffset": 0,
  "networkactive": true,
  "connections": 8,
  "networks": [
    {
      "name": "ipv4",
      "limited": false,
      "reachable": true,
      "proxy": "",
      "proxy_randomize_credentials": false
    }
  ],
  "relayfee": 0.00001000,
  "incrementalfee": 0.00001000,
  "localaddresses": [],
  "warnings": ""
}
```

#### `getconnectioncount`
Returns the number of connections to other nodes.

**Parameters:** None

**Response:** `8` (integer)

#### `getpeerinfo`
Returns data about each connected network node.

**Parameters:** None

**Response:**
```json
[
  {
    "id": 1,
    "addr": "192.168.1.100:33317",
    "addrlocal": "192.168.1.50:54321",
    "services": "0000000000000409",
    "relaytxes": true,
    "lastsend": 1640995200,
    "lastrecv": 1640995200,
    "bytessent": 12345,
    "bytesrecv": 54321,
    "conntime": 1640990000,
    "timeoffset": 0,
    "pingtime": 0.123,
    "version": 70015,
    "subver": "/B1T Core:2.1.0/",
    "inbound": false,
    "startingheight": 12340,
    "banscore": 0,
    "synced_headers": 12345,
    "synced_blocks": 12345
  }
]
```

### Block Operations

#### `getblock`
Returns information about a block.

**Parameters:**
1. `blockhash` (string, required) - The block hash
2. `verbosity` (integer, optional, default=1) - 0=hex, 1=json, 2=json with tx details

**Response (verbosity=1):**
```json
{
  "hash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
  "confirmations": 100,
  "size": 285,
  "height": 12345,
  "version": 1,
  "versionHex": "00000001",
  "merkleroot": "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
  "tx": [
    "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"
  ],
  "time": 1640995200,
  "mediantime": 1640995000,
  "nonce": 2083236893,
  "bits": "1d00ffff",
  "difficulty": 1.0,
  "chainwork": "0000000000000000000000000000000000000000000000000000000100010001",
  "previousblockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26e",
  "nextblockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce270"
}
```

#### `getblockhash`
Returns the hash of a block at a specific height.

**Parameters:**
1. `height` (integer, required) - The block height

**Response:** `"000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"`

#### `getblockheader`
Returns information about a block header.

**Parameters:**
1. `blockhash` (string, required) - The block hash
2. `verbose` (boolean, optional, default=true) - true=json, false=hex

**Response:**
```json
{
  "hash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
  "confirmations": 100,
  "height": 12345,
  "version": 1,
  "versionHex": "00000001",
  "merkleroot": "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
  "time": 1640995200,
  "mediantime": 1640995000,
  "nonce": 2083236893,
  "bits": "1d00ffff",
  "difficulty": 1.0,
  "chainwork": "0000000000000000000000000000000000000000000000000000000100010001",
  "previousblockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26e",
  "nextblockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce270"
}
```

### Transaction Operations

#### `getrawtransaction`
Returns raw transaction data.

**Parameters:**
1. `txid` (string, required) - The transaction ID
2. `verbose` (boolean, optional, default=false) - true=json, false=hex
3. `blockhash` (string, optional) - Block hash to look in

**Response (verbose=true):**
```json
{
  "txid": "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
  "hash": "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
  "version": 1,
  "size": 250,
  "vsize": 250,
  "locktime": 0,
  "vin": [
    {
      "txid": "0000000000000000000000000000000000000000000000000000000000000000",
      "vout": 4294967295,
      "scriptSig": {
        "asm": "04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73",
        "hex": "04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73"
      },
      "sequence": 4294967295
    }
  ],
  "vout": [
    {
      "value": 50.00000000,
      "n": 0,
      "scriptPubKey": {
        "asm": "04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f OP_CHECKSIG",
        "hex": "4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac",
        "type": "pubkey"
      }
    }
  ],
  "blockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
  "confirmations": 100,
  "time": 1640995200,
  "blocktime": 1640995200
}
```

#### `gettransaction`
Get detailed information about a wallet transaction.

**Parameters:**
1. `txid` (string, required) - The transaction ID
2. `include_watchonly` (boolean, optional, default=false) - Include watch-only addresses

**Response:**
```json
{
  "amount": 0.00000000,
  "fee": -0.00010000,
  "confirmations": 100,
  "blockhash": "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
  "blockindex": 1,
  "blocktime": 1640995200,
  "txid": "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
  "time": 1640995200,
  "timereceived": 1640995200,
  "details": [
    {
      "account": "",
      "address": "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
      "category": "send",
      "amount": -1.00000000,
      "fee": -0.00010000
    }
  ],
  "hex": "01000000..."
}
```

#### `sendrawtransaction`
Submit a raw transaction to the network.

**Parameters:**
1. `hexstring` (string, required) - The hex string of the raw transaction
2. `allowhighfees` (boolean, optional, default=false) - Allow high fees

**Response:** `"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"` (txid)

### Wallet Operations

#### `getwalletinfo`
Returns wallet information.

**Parameters:** None

**Response:**
```json
{
  "walletname": "",
  "walletversion": 169900,
  "balance": 10.50000000,
  "unconfirmed_balance": 0.00000000,
  "immature_balance": 0.00000000,
  "txcount": 25,
  "keypoololdest": 1640990000,
  "keypoolsize": 1000,
  "unlocked_until": 0,
  "paytxfee": 0.00000000,
  "hdmasterkeyid": "a1b2c3d4e5f6..."
}
```

#### `getbalance`
Returns the wallet balance.

**Parameters:**
1. `account` (string, optional) - Account name (deprecated)
2. `minconf` (integer, optional, default=1) - Minimum confirmations
3. `include_watchonly` (boolean, optional, default=false) - Include watch-only addresses

**Response:** `10.50000000` (number)

#### `getnewaddress`
Generates a new address.

**Parameters:**
1. `account` (string, optional) - Account name (deprecated)
2. `address_type` (string, optional) - Address type (legacy, p2sh-segwit, bech32)

**Response:** `"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"`

#### `sendtoaddress`
Send an amount to a given address.

**Parameters:**
1. `address` (string, required) - The B1T address
2. `amount` (number, required) - The amount to send
3. `comment` (string, optional) - Transaction comment
4. `comment_to` (string, optional) - Comment for recipient
5. `subtractfeefromamount` (boolean, optional, default=false) - Subtract fee from amount

**Response:** `"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"` (txid)

### Mining Operations

#### `getmininginfo`
Returns mining-related information.

**Parameters:** None

**Response:**
```json
{
  "blocks": 12345,
  "currentblocksize": 1000,
  "currentblocktx": 10,
  "difficulty": 1.0,
  "errors": "",
  "generate": false,
  "genproclimit": -1,
  "hashespersec": 0,
  "networkhashps": 1000000,
  "pooledtx": 5,
  "testnet": false,
  "chain": "main"
}
```

#### `getnetworkhashps`
Returns the estimated network hash rate.

**Parameters:**
1. `nblocks` (integer, optional, default=120) - Number of blocks to average
2. `height` (integer, optional, default=-1) - Block height (-1 for current)

**Response:** `1000000` (number)

### Utility Methods

#### `validateaddress`
Validates a B1T address.

**Parameters:**
1. `address` (string, required) - The B1T address

**Response:**
```json
{
  "isvalid": true,
  "address": "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
  "scriptPubKey": "76a914...",
  "ismine": false,
  "iswatchonly": false,
  "isscript": false,
  "pubkey": "04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f",
  "iscompressed": false,
  "account": ""
}
```

#### `estimatefee`
Estimates the fee per kilobyte.

**Parameters:**
1. `nblocks` (integer, required) - Number of blocks for confirmation target

**Response:** `0.00010000` (number)

#### `help`
Lists available commands or gets help for a specific command.

**Parameters:**
1. `command` (string, optional) - The command to get help for

**Response:** String with help information

## Examples

### Using curl

```bash
# Get blockchain info
curl -u b1tuser:b1tpassword \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getblockchaininfo","params":[]}' \
  http://localhost:33318/

# Get block count
curl -u b1tuser:b1tpassword \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getblockcount","params":[]}' \
  http://localhost:33318/

# Get specific block
curl -u b1tuser:b1tpassword \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getblock","params":["000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"]}' \
  http://localhost:33318/
```

### Using JavaScript (Node.js)

```javascript
const axios = require('axios');

const rpcCall = async (method, params = []) => {
  const config = {
    auth: {
      username: 'b1tuser',
      password: 'b1tpassword'
    },
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const data = {
    jsonrpc: '1.0',
    id: 'test',
    method: method,
    params: params
  };
  
  try {
    const response = await axios.post('http://localhost:33318/', data, config);
    return response.data.result;
  } catch (error) {
    console.error('RPC Error:', error.response?.data?.error || error.message);
    throw error;
  }
};

// Examples
(async () => {
  try {
    const blockCount = await rpcCall('getblockcount');
    console.log('Block count:', blockCount);
    
    const networkInfo = await rpcCall('getnetworkinfo');
    console.log('Network info:', networkInfo);
    
    const balance = await rpcCall('getbalance');
    console.log('Wallet balance:', balance);
  } catch (error) {
    console.error('Failed to call RPC:', error.message);
  }
})();
```

### Using Python

```python
import requests
import json
from requests.auth import HTTPBasicAuth

def rpc_call(method, params=[]):
    url = 'http://localhost:33318/'
    auth = HTTPBasicAuth('b1tuser', 'b1tpassword')
    headers = {'Content-Type': 'application/json'}
    
    data = {
        'jsonrpc': '1.0',
        'id': 'test',
        'method': method,
        'params': params
    }
    
    try:
        response = requests.post(url, json=data, auth=auth, headers=headers)
        response.raise_for_status()
        return response.json()['result']
    except requests.exceptions.RequestException as e:
        print(f'RPC Error: {e}')
        raise

# Examples
if __name__ == '__main__':
    try:
        block_count = rpc_call('getblockcount')
        print(f'Block count: {block_count}')
        
        network_info = rpc_call('getnetworkinfo')
        print(f'Network info: {json.dumps(network_info, indent=2)}')
        
        balance = rpc_call('getbalance')
        print(f'Wallet balance: {balance}')
    except Exception as e:
        print(f'Failed to call RPC: {e}')
```

## Rate Limiting

The B1T Core Node doesn't implement built-in rate limiting, but you should implement client-side rate limiting to avoid overwhelming the node:

- **Recommended**: Maximum 10 requests per second
- **Burst**: Up to 50 requests in a 10-second window
- **Heavy operations**: Limit to 1 request per second for operations like `getblock` with full transaction details

## Security Considerations

### Network Security

1. **Firewall Configuration**
   - Only expose RPC port (33318) to trusted networks
   - Use VPN or SSH tunneling for remote access
   - Consider using a reverse proxy with additional authentication

2. **Authentication**
   - Use strong, unique passwords for RPC authentication
   - Rotate credentials regularly
   - Consider implementing additional authentication layers

3. **SSL/TLS**
   - The default setup doesn't use SSL/TLS
   - For production, implement SSL/TLS termination at a reverse proxy
   - Use certificates from a trusted CA

### Application Security

1. **Input Validation**
   - Always validate and sanitize input parameters
   - Use parameterized queries when storing RPC responses
   - Implement proper error handling

2. **Access Control**
   - Implement role-based access control in your application
   - Log all RPC calls for audit purposes
   - Monitor for suspicious activity

3. **Data Protection**
   - Never log sensitive information (private keys, passwords)
   - Encrypt sensitive data at rest
   - Use secure communication channels

### Operational Security

1. **Monitoring**
   - Monitor RPC endpoint for unusual activity
   - Set up alerts for failed authentication attempts
   - Track resource usage and performance metrics

2. **Updates**
   - Keep the B1T Core Node updated to the latest version
   - Monitor security advisories and apply patches promptly
   - Regularly review and update security configurations

3. **Backup and Recovery**
   - Regularly backup wallet and configuration files
   - Test backup restoration procedures
   - Implement disaster recovery plans

---

**Note**: This documentation is based on B1T Core v2.1.0.0. Some methods may vary between versions. Always refer to the official B1T Core documentation for the most up-to-date information.

For additional support and updates, visit the [B1T Core GitHub repository](https://github.com/bittoshimoto/Bit).