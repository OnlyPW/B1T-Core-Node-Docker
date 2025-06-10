#!/usr/bin/env node

/**
 * B1T Core Node - RPC Test Script
 * Comprehensive testing of RPC functionality and node health
 */

const axios = require('axios');
const fs = require('fs-extra');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Helper functions
const log = {
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  header: (msg) => console.log(`\n${colors.cyan}${colors.bright}${msg}${colors.reset}\n`),
  data: (label, value) => console.log(`  ${colors.magenta}${label}:${colors.reset} ${value}`)
};

class B1TRPCTester {
  constructor() {
    this.rpcUrl = `http://localhost:${process.env.RPC_PORT || 33318}/`;
    this.rpcUser = process.env.RPC_USER || 'b1tuser';
    this.rpcPassword = process.env.RPC_PASSWORD || 'b1tpassword';
    this.timeout = 10000; // 10 seconds
    
    this.axiosConfig = {
      timeout: this.timeout,
      auth: {
        username: this.rpcUser,
        password: this.rpcPassword
      },
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    this.testResults = {
      passed: 0,
      failed: 0,
      warnings: 0,
      tests: []
    };
  }

  async run() {
    try {
      log.header('🧪 B1T Core Node RPC Test Suite');
      
      await this.displayConfiguration();
      await this.testConnection();
      await this.testBasicInfo();
      await this.testNetworkInfo();
      await this.testBlockchainInfo();
      await this.testPeerInfo();
      await this.testWalletInfo();
      await this.testAdvancedFeatures();
      await this.performanceTests();
      
      this.displaySummary();
      
    } catch (error) {
      log.error(`Test suite failed: ${error.message}`);
      process.exit(1);
    }
  }

  async displayConfiguration() {
    log.header('📋 Configuration');
    log.data('RPC URL', this.rpcUrl);
    log.data('RPC User', this.rpcUser);
    log.data('RPC Password', '*'.repeat(this.rpcPassword.length));
    log.data('Timeout', `${this.timeout}ms`);
  }

  async testConnection() {
    log.header('🔌 Connection Test');
    
    try {
      const response = await this.rpcCall('getblockcount');
      if (response && typeof response.result === 'number') {
        this.recordTest('Connection', true, `Connected successfully. Block count: ${response.result}`);
      } else {
        this.recordTest('Connection', false, 'Invalid response format');
      }
    } catch (error) {
      this.recordTest('Connection', false, `Connection failed: ${error.message}`);
    }
  }

  async testBasicInfo() {
    log.header('📊 Basic Information Tests');
    
    // Test getinfo (if available)
    try {
      const info = await this.rpcCall('getinfo');
      if (info && info.result) {
        this.recordTest('getinfo', true, 'Basic info retrieved');
        log.data('Version', info.result.version || 'Unknown');
        log.data('Protocol Version', info.result.protocolversion || 'Unknown');
        log.data('Blocks', info.result.blocks || 'Unknown');
        log.data('Connections', info.result.connections || 'Unknown');
      }
    } catch (error) {
      this.recordTest('getinfo', false, `getinfo failed: ${error.message}`);
    }
    
    // Test getblockcount
    try {
      const blockCount = await this.rpcCall('getblockcount');
      if (blockCount && typeof blockCount.result === 'number') {
        this.recordTest('getblockcount', true, `Block count: ${blockCount.result}`);
        
        if (blockCount.result === 0) {
          this.recordTest('Blockchain Sync', false, 'Node appears to be not synced (block count is 0)', 'warning');
        } else {
          this.recordTest('Blockchain Sync', true, `Node has ${blockCount.result} blocks`);
        }
      }
    } catch (error) {
      this.recordTest('getblockcount', false, `getblockcount failed: ${error.message}`);
    }
    
    // Test getbestblockhash
    try {
      const bestBlock = await this.rpcCall('getbestblockhash');
      if (bestBlock && bestBlock.result) {
        this.recordTest('getbestblockhash', true, `Best block hash: ${bestBlock.result.substring(0, 16)}...`);
      }
    } catch (error) {
      this.recordTest('getbestblockhash', false, `getbestblockhash failed: ${error.message}`);
    }
  }

  async testNetworkInfo() {
    log.header('🌐 Network Information Tests');
    
    try {
      const networkInfo = await this.rpcCall('getnetworkinfo');
      if (networkInfo && networkInfo.result) {
        this.recordTest('getnetworkinfo', true, 'Network info retrieved');
        
        const info = networkInfo.result;
        log.data('Network', info.networkactive ? 'Active' : 'Inactive');
        log.data('Version', info.version || 'Unknown');
        log.data('Subversion', info.subversion || 'Unknown');
        log.data('Protocol Version', info.protocolversion || 'Unknown');
        log.data('Local Services', info.localservices || 'Unknown');
        log.data('Relay Fee', info.relayfee || 'Unknown');
        
        if (info.networks && Array.isArray(info.networks)) {
          log.data('Supported Networks', info.networks.map(n => n.name).join(', '));
        }
      }
    } catch (error) {
      this.recordTest('getnetworkinfo', false, `getnetworkinfo failed: ${error.message}`);
    }
    
    // Test getconnectioncount
    try {
      const connectionCount = await this.rpcCall('getconnectioncount');
      if (connectionCount && typeof connectionCount.result === 'number') {
        const count = connectionCount.result;
        this.recordTest('getconnectioncount', true, `Connection count: ${count}`);
        
        if (count === 0) {
          this.recordTest('Peer Connections', false, 'No peer connections found', 'warning');
        } else {
          this.recordTest('Peer Connections', true, `Connected to ${count} peers`);
        }
      }
    } catch (error) {
      this.recordTest('getconnectioncount', false, `getconnectioncount failed: ${error.message}`);
    }
  }

  async testBlockchainInfo() {
    log.header('⛓️ Blockchain Information Tests');
    
    try {
      const blockchainInfo = await this.rpcCall('getblockchaininfo');
      if (blockchainInfo && blockchainInfo.result) {
        this.recordTest('getblockchaininfo', true, 'Blockchain info retrieved');
        
        const info = blockchainInfo.result;
        log.data('Chain', info.chain || 'Unknown');
        log.data('Blocks', info.blocks || 'Unknown');
        log.data('Headers', info.headers || 'Unknown');
        log.data('Best Block Hash', info.bestblockhash ? info.bestblockhash.substring(0, 16) + '...' : 'Unknown');
        log.data('Difficulty', info.difficulty || 'Unknown');
        log.data('Verification Progress', info.verificationprogress ? (info.verificationprogress * 100).toFixed(2) + '%' : 'Unknown');
        
        // Check sync status
        if (info.verificationprogress && info.verificationprogress < 0.99) {
          this.recordTest('Sync Status', false, `Node is syncing (${(info.verificationprogress * 100).toFixed(2)}% complete)`, 'warning');
        } else {
          this.recordTest('Sync Status', true, 'Node appears to be fully synced');
        }
        
        // Check if headers match blocks
        if (info.blocks && info.headers && info.blocks < info.headers) {
          this.recordTest('Block Sync', false, `Blocks (${info.blocks}) behind headers (${info.headers})`, 'warning');
        } else {
          this.recordTest('Block Sync', true, 'Blocks and headers are in sync');
        }
      }
    } catch (error) {
      this.recordTest('getblockchaininfo', false, `getblockchaininfo failed: ${error.message}`);
    }
  }

  async testPeerInfo() {
    log.header('👥 Peer Information Tests');
    
    try {
      const peerInfo = await this.rpcCall('getpeerinfo');
      if (peerInfo && Array.isArray(peerInfo.result)) {
        const peers = peerInfo.result;
        this.recordTest('getpeerinfo', true, `Retrieved info for ${peers.length} peers`);
        
        if (peers.length === 0) {
          this.recordTest('Peer Analysis', false, 'No peers connected', 'warning');
        } else {
          log.data('Total Peers', peers.length);
          
          // Analyze peer connections
          const inbound = peers.filter(p => p.inbound).length;
          const outbound = peers.length - inbound;
          
          log.data('Inbound Connections', inbound);
          log.data('Outbound Connections', outbound);
          
          // Check peer versions
          const versions = [...new Set(peers.map(p => p.subver).filter(v => v))];
          if (versions.length > 0) {
            log.data('Peer Versions', versions.join(', '));
          }
          
          this.recordTest('Peer Analysis', true, `${peers.length} peers connected (${inbound} inbound, ${outbound} outbound)`);
        }
      }
    } catch (error) {
      this.recordTest('getpeerinfo', false, `getpeerinfo failed: ${error.message}`);
    }
  }

  async testWalletInfo() {
    log.header('💰 Wallet Information Tests');
    
    try {
      const walletInfo = await this.rpcCall('getwalletinfo');
      if (walletInfo && walletInfo.result) {
        this.recordTest('getwalletinfo', true, 'Wallet info retrieved');
        
        const info = walletInfo.result;
        log.data('Wallet Name', info.walletname || 'Default');
        log.data('Wallet Version', info.walletversion || 'Unknown');
        log.data('Balance', info.balance || '0');
        log.data('Unconfirmed Balance', info.unconfirmed_balance || '0');
        log.data('Transaction Count', info.txcount || '0');
        
        if (info.unlocked_until !== undefined) {
          const isLocked = info.unlocked_until === 0;
          log.data('Wallet Status', isLocked ? 'Locked' : 'Unlocked');
        }
      }
    } catch (error) {
      // Wallet might be disabled
      if (error.message.includes('disabled') || error.message.includes('Method not found')) {
        this.recordTest('Wallet Status', true, 'Wallet is disabled (as configured)', 'warning');
      } else {
        this.recordTest('getwalletinfo', false, `getwalletinfo failed: ${error.message}`);
      }
    }
  }

  async testAdvancedFeatures() {
    log.header('🔧 Advanced Features Tests');
    
    // Test transaction indexing
    try {
      const blockCount = await this.rpcCall('getblockcount');
      if (blockCount && blockCount.result > 0) {
        // Get a recent block
        const blockHash = await this.rpcCall('getblockhash', [Math.max(1, blockCount.result - 10)]);
        if (blockHash && blockHash.result) {
          const block = await this.rpcCall('getblock', [blockHash.result]);
          if (block && block.result && block.result.tx && block.result.tx.length > 0) {
            // Try to get transaction details
            const txid = block.result.tx[0];
            const tx = await this.rpcCall('getrawtransaction', [txid, true]);
            if (tx && tx.result) {
              this.recordTest('Transaction Indexing', true, 'Transaction indexing is working');
            }
          }
        }
      }
    } catch (error) {
      this.recordTest('Transaction Indexing', false, `Transaction indexing test failed: ${error.message}`, 'warning');
    }
    
    // Test memory pool
    try {
      const mempoolInfo = await this.rpcCall('getmempoolinfo');
      if (mempoolInfo && mempoolInfo.result) {
        this.recordTest('Memory Pool', true, `Mempool has ${mempoolInfo.result.size || 0} transactions`);
        log.data('Mempool Size', mempoolInfo.result.size || 0);
        log.data('Mempool Bytes', mempoolInfo.result.bytes || 0);
      }
    } catch (error) {
      this.recordTest('Memory Pool', false, `getmempoolinfo failed: ${error.message}`);
    }
  }

  async performanceTests() {
    log.header('⚡ Performance Tests');
    
    // Test RPC response time
    const startTime = Date.now();
    try {
      await this.rpcCall('getblockcount');
      const responseTime = Date.now() - startTime;
      
      if (responseTime < 1000) {
        this.recordTest('RPC Response Time', true, `${responseTime}ms (Good)`);
      } else if (responseTime < 5000) {
        this.recordTest('RPC Response Time', true, `${responseTime}ms (Acceptable)`, 'warning');
      } else {
        this.recordTest('RPC Response Time', false, `${responseTime}ms (Slow)`, 'warning');
      }
    } catch (error) {
      this.recordTest('RPC Response Time', false, `Performance test failed: ${error.message}`);
    }
  }

  async rpcCall(method, params = []) {
    const data = {
      jsonrpc: '1.0',
      id: 'test',
      method: method,
      params: params
    };
    
    try {
      const response = await axios.post(this.rpcUrl, data, this.axiosConfig);
      return response.data;
    } catch (error) {
      if (error.response && error.response.data && error.response.data.error) {
        throw new Error(error.response.data.error.message);
      }
      throw error;
    }
  }

  recordTest(name, passed, message, type = null) {
    const result = {
      name,
      passed,
      message,
      type: type || (passed ? 'success' : 'error')
    };
    
    this.testResults.tests.push(result);
    
    if (passed) {
      if (type === 'warning') {
        this.testResults.warnings++;
        log.warning(`${name}: ${message}`);
      } else {
        this.testResults.passed++;
        log.success(`${name}: ${message}`);
      }
    } else {
      if (type === 'warning') {
        this.testResults.warnings++;
        log.warning(`${name}: ${message}`);
      } else {
        this.testResults.failed++;
        log.error(`${name}: ${message}`);
      }
    }
  }

  displaySummary() {
    log.header('📈 Test Summary');
    
    const total = this.testResults.passed + this.testResults.failed + this.testResults.warnings;
    
    log.data('Total Tests', total);
    log.data('Passed', `${colors.green}${this.testResults.passed}${colors.reset}`);
    log.data('Failed', `${colors.red}${this.testResults.failed}${colors.reset}`);
    log.data('Warnings', `${colors.yellow}${this.testResults.warnings}${colors.reset}`);
    
    const successRate = total > 0 ? ((this.testResults.passed / total) * 100).toFixed(1) : 0;
    log.data('Success Rate', `${successRate}%`);
    
    console.log();
    
    if (this.testResults.failed === 0) {
      if (this.testResults.warnings === 0) {
        log.success('All tests passed! Your B1T Core Node is working perfectly.');
      } else {
        log.warning('Tests completed with warnings. Node is functional but may need attention.');
      }
    } else {
      log.error('Some tests failed. Please check the node configuration and logs.');
      process.exit(1);
    }
  }
}

// Main execution
if (require.main === module) {
  const tester = new B1TRPCTester();
  tester.run().catch(error => {
    console.error(`${colors.red}Test suite failed:${colors.reset}`, error.message);
    process.exit(1);
  });
}

module.exports = B1TRPCTester;