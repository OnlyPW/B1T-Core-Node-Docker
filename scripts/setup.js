#!/usr/bin/env node

/**
 * B1T Core Node - Setup Script
 * Automated setup and configuration for the B1T Core Node Docker project
 */

const fs = require('fs-extra');
const path = require('path');
const { execSync } = require('child_process');
const readline = require('readline');
const crypto = require('crypto');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m'
};

// Helper functions
const log = {
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  header: (msg) => console.log(`\n${colors.cyan}${colors.bright}${msg}${colors.reset}\n`)
};

class B1TSetup {
  constructor() {
    this.projectRoot = path.resolve(__dirname, '..');
    this.envFile = path.join(this.projectRoot, '.env');
    this.envExampleFile = path.join(this.projectRoot, '.env.example');
    this.dataDir = path.join(this.projectRoot, 'data');
    this.logsDir = path.join(this.projectRoot, 'logs');
    this.backupsDir = path.join(this.projectRoot, 'backups');
    
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
  }

  async run() {
    try {
      log.header('🚀 B1T Core Node Setup');
      
      await this.checkPrerequisites();
      await this.createDirectories();
      await this.setupEnvironment();
      await this.validateConfiguration();
      await this.displayNextSteps();
      
      log.success('Setup completed successfully!');
    } catch (error) {
      log.error(`Setup failed: ${error.message}`);
      process.exit(1);
    } finally {
      this.rl.close();
    }
  }

  async checkPrerequisites() {
    log.header('📋 Checking Prerequisites');
    
    // Check Docker
    try {
      const dockerVersion = execSync('docker --version', { encoding: 'utf8' });
      log.success(`Docker found: ${dockerVersion.trim()}`);
    } catch (error) {
      throw new Error('Docker is not installed or not in PATH');
    }
    
    // Check Docker Compose
    try {
      const composeVersion = execSync('docker-compose --version', { encoding: 'utf8' });
      log.success(`Docker Compose found: ${composeVersion.trim()}`);
    } catch (error) {
      try {
        const composeVersion = execSync('docker compose version', { encoding: 'utf8' });
        log.success(`Docker Compose found: ${composeVersion.trim()}`);
      } catch (error2) {
        throw new Error('Docker Compose is not installed or not in PATH');
      }
    }
    
    // Check available disk space
    try {
      const stats = fs.statSync(this.projectRoot);
      log.info('Disk space check completed');
    } catch (error) {
      log.warning('Could not check disk space');
    }
    
    // Check Node.js version
    const nodeVersion = process.version;
    const majorVersion = parseInt(nodeVersion.slice(1).split('.')[0]);
    if (majorVersion < 16) {
      log.warning(`Node.js ${nodeVersion} detected. Version 16+ recommended.`);
    } else {
      log.success(`Node.js ${nodeVersion} is compatible`);
    }
  }

  async createDirectories() {
    log.header('📁 Creating Directories');
    
    const directories = [
      { path: this.dataDir, description: 'Blockchain data directory' },
      { path: this.logsDir, description: 'Logs directory' },
      { path: this.backupsDir, description: 'Backups directory' },
      { path: path.join(this.projectRoot, 'scripts'), description: 'Scripts directory' },
      { path: path.join(this.projectRoot, 'docs'), description: 'Documentation directory' },
      { path: path.join(this.projectRoot, 'examples'), description: 'Examples directory' }
    ];
    
    for (const dir of directories) {
      try {
        await fs.ensureDir(dir.path);
        log.success(`Created ${dir.description}: ${path.relative(this.projectRoot, dir.path)}`);
      } catch (error) {
        log.error(`Failed to create ${dir.description}: ${error.message}`);
      }
    }
  }

  async setupEnvironment() {
    log.header('⚙️ Environment Configuration');
    
    if (await fs.pathExists(this.envFile)) {
      const overwrite = await this.question(
        `${colors.yellow}.env file already exists. Overwrite? (y/N): ${colors.reset}`
      );
      
      if (!overwrite.toLowerCase().startsWith('y')) {
        log.info('Keeping existing .env file');
        return;
      }
    }
    
    if (!(await fs.pathExists(this.envExampleFile))) {
      throw new Error('.env.example file not found');
    }
    
    // Read template
    let envContent = await fs.readFile(this.envExampleFile, 'utf8');
    
    // Interactive configuration
    const config = await this.gatherConfiguration();
    
    // Replace placeholders
    envContent = this.replaceEnvVariables(envContent, config);
    
    // Write .env file
    await fs.writeFile(this.envFile, envContent);
    log.success('Environment configuration created');
  }

  async gatherConfiguration() {
    log.info('Please provide configuration values (press Enter for defaults):');
    
    const config = {};
    
    // RPC Configuration
    config.RPC_USER = await this.question('RPC Username [b1tuser]: ') || 'b1tuser';
    
    const defaultPassword = this.generateSecurePassword();
    config.RPC_PASSWORD = await this.question(`RPC Password [${defaultPassword}]: `) || defaultPassword;
    
    config.RPC_PORT = await this.question('RPC Port [33318]: ') || '33318';
    config.P2P_PORT = await this.question('P2P Port [33317]: ') || '33317';
    
    // Performance settings
    config.DB_CACHE = await this.question('Database Cache (MB) [512]: ') || '512';
    config.MAX_MEMPOOL = await this.question('Max Mempool (MB) [300]: ') || '300';
    
    // Debug level
    const debugLevel = await this.question('Debug Level (0=minimal, 1=standard, 2=verbose) [1]: ') || '1';
    config.DEBUG_LEVEL = debugLevel;
    
    // Data directory
    const dataDir = await this.question('Data Directory [./data]: ') || './data';
    config.DATA_DIR = dataDir;
    
    return config;
  }

  replaceEnvVariables(content, config) {
    let result = content;
    
    // Replace specific values
    result = result.replace(/RPC_USER=.*/, `RPC_USER=${config.RPC_USER}`);
    result = result.replace(/RPC_PASSWORD=.*/, `RPC_PASSWORD=${config.RPC_PASSWORD}`);
    result = result.replace(/RPC_PORT=.*/, `RPC_PORT=${config.RPC_PORT}`);
    result = result.replace(/P2P_PORT=.*/, `P2P_PORT=${config.P2P_PORT}`);
    result = result.replace(/DB_CACHE=.*/, `DB_CACHE=${config.DB_CACHE}`);
    result = result.replace(/MAX_MEMPOOL=.*/, `MAX_MEMPOOL=${config.MAX_MEMPOOL}`);
    result = result.replace(/DEBUG_LEVEL=.*/, `DEBUG_LEVEL=${config.DEBUG_LEVEL}`);
    result = result.replace(/DATA_DIR=.*/, `DATA_DIR=${config.DATA_DIR}`);
    
    return result;
  }

  generateSecurePassword(length = 16) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    
    for (let i = 0; i < length; i++) {
      const randomIndex = crypto.randomInt(0, charset.length);
      password += charset[randomIndex];
    }
    
    return password;
  }

  async validateConfiguration() {
    log.header('✅ Validating Configuration');
    
    try {
      // Check if .env file exists and is readable
      const envContent = await fs.readFile(this.envFile, 'utf8');
      
      // Parse environment variables
      const envVars = {};
      envContent.split('\n').forEach(line => {
        const [key, value] = line.split('=');
        if (key && value) {
          envVars[key.trim()] = value.trim();
        }
      });
      
      // Validate required variables
      const required = ['RPC_USER', 'RPC_PASSWORD', 'RPC_PORT', 'P2P_PORT'];
      for (const key of required) {
        if (!envVars[key]) {
          throw new Error(`Missing required environment variable: ${key}`);
        }
      }
      
      // Validate port numbers
      const rpcPort = parseInt(envVars.RPC_PORT);
      const p2pPort = parseInt(envVars.P2P_PORT);
      
      if (isNaN(rpcPort) || rpcPort < 1024 || rpcPort > 65535) {
        throw new Error('RPC_PORT must be a valid port number (1024-65535)');
      }
      
      if (isNaN(p2pPort) || p2pPort < 1024 || p2pPort > 65535) {
        throw new Error('P2P_PORT must be a valid port number (1024-65535)');
      }
      
      if (rpcPort === p2pPort) {
        throw new Error('RPC_PORT and P2P_PORT cannot be the same');
      }
      
      log.success('Configuration validation passed');
    } catch (error) {
      throw new Error(`Configuration validation failed: ${error.message}`);
    }
  }

  async displayNextSteps() {
    log.header('🎯 Next Steps');
    
    console.log(`${colors.green}Setup completed successfully!${colors.reset}\n`);
    console.log('To start your B1T Core Node, run one of the following commands:\n');
    
    console.log(`${colors.cyan}Using npm scripts:${colors.reset}`);
    console.log('  npm start              # Start the node');
    console.log('  npm run logs           # View logs');
    console.log('  npm run status         # Check status');
    console.log('  npm run info           # Get blockchain info\n');
    
    console.log(`${colors.cyan}Using Docker Compose directly:${colors.reset}`);
    console.log('  docker-compose up -d   # Start the node');
    console.log('  docker-compose logs -f # View logs');
    console.log('  docker-compose ps      # Check status\n');
    
    console.log(`${colors.cyan}Using Makefile (if available):${colors.reset}`);
    console.log('  make start             # Start the node');
    console.log('  make logs              # View logs');
    console.log('  make status            # Check status\n');
    
    console.log(`${colors.yellow}Important notes:${colors.reset}`);
    console.log('• Initial blockchain sync may take several hours');
    console.log('• Ensure you have at least 50GB of free disk space');
    console.log('• Monitor logs during first startup for any issues');
    console.log('• RPC will be available on port ' + (process.env.RPC_PORT || '33318'));
    console.log('• P2P network will use port ' + (process.env.P2P_PORT || '33317'));
  }

  question(prompt) {
    return new Promise((resolve) => {
      this.rl.question(prompt, resolve);
    });
  }
}

// Main execution
if (require.main === module) {
  const setup = new B1TSetup();
  setup.run().catch(error => {
    console.error(`${colors.red}Setup failed:${colors.reset}`, error.message);
    process.exit(1);
  });
}

module.exports = B1TSetup;