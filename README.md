# Geth Clique PoA Network for SSI/DID Management System

## Architecture Overview

This project implements a **permissioned Ethereum blockchain** using **Go-Ethereum (Geth)** with **Clique Proof-of-Authority (PoA)** consensus, specifically designed for a **Self-Sovereign Identity (SSI) and Decentralized Identifier (DID) management system** following the **Trust Triangle approach**.

### 🏗️ Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Geth Clique PoA Network                      │
│                   (172.16.239.0/24 subnet)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌─────────────────────────────────────┐    │
│  │   Bootnode   │    │            Validators               │    │
│  │ (.10:30301)  │◄──►│  V1(.11)  V2(.12)  V3(.13)  V4(.14) │    │
│  └──────────────┘    └─────────────────────────────────────┘    │
│                                     ▲                           │
│  ┌──────────────┐     ┌─────────────┴─┐   ┌──────────────────┐  │
│  │   Web3Signer │ ──► │ RPC Node      │   │   Monitoring     │  │
│  │ (.40:18545)  │     │ (.15:8545)    │   │ Prometheus(.32)  │  │
│  └──────────────┘     └───────────────┘   │ Grafana(.33)     │  │
│                                           │ Loki(.34)        │  │
│                                           └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
did-geth/
├── docker-compose.yml          # Main orchestration file
├── .env                        # Environment configuration
├── start-network.sh           # Network management script
├── network/
│   ├── config/
│   │   ├── geth/              # Geth global configurations
│   │   │   ├── genesis.json           # Clique PoA genesis block
│   │   │   ├── config.toml            # Geth TOML configuration
│   │   │   ├── static-nodes.json      # P2P static node discovery
│   │   │   ├── password.txt           # Default account password
│   │   │   ├── clique-standard-genesis.json
│   │   │   └── genesis.bak            # Genesis backup
│   │   ├── nodes/             # Individual node configurations
│   │   │   ├── rpcnode/              # RPC node credentials
│   │   │   │   ├── accountKeystore   # Encrypted account keystore
│   │   │   │   ├── accountPrivateKey # Account private key
│   │   │   │   ├── accountPassword   # Account password
│   │   │   │   ├── address           # Node address
│   │   │   │   ├── nodekey           # P2P node private key
│   │   │   │   └── nodekey.pub       # P2P node public key
│   │   │   ├── validator1/           # Validator 1 credentials
│   │   │   │   ├── accountKeystore   # Encrypted keystore
│   │   │   │   ├── accountPrivateKey # Private key
│   │   │   │   ├── address           # Validator address
│   │   │   │   ├── nodekey           # P2P private key
│   │   │   │   └── nodekey.pub       # P2P public key
│   │   │   ├── validator2/           # Validator 2 credentials
│   │   │   ├── validator3/           # Validator 3 credentials
│   │   │   └── validator4/           # Validator 4 credentials
│   │   └── web3signer/        # Web3Signer transaction signing
│   │       ├── config.yaml           # Web3Signer configuration
│   │       ├── password              # Signing password
│   │       ├── key                   # Encrypted signing key
│   │       ├── createKey.js          # Key generation script
│   │       └── keys/                 # YAML key configurations
│   │           ├── ethsigner.yaml    # EthSigner key config
│   │           ├── myaccount.yaml    # Personal account key
│   │           ├── node1.yaml        # Node 1 signing key
│   │           ├── node2.yaml        # Node 2 signing key
│   │           ├── node3.yaml        # Node 3 signing key
│   │           ├── node4.yaml        # Node 4 signing key
│   │           └── rpcnode.yaml      # RPC node signing key
│   ├── tools/                 # Development and maintenance tools
│   │   ├── generate_node_details.js  # Node credential generator
│   │   └── package.json              # Node.js dependencies
│   └── logs/                  # Persistent service logs
│       ├── geth/                     # Geth node logs
│       └── web3signer/               # Web3Signer logs
└── README.md                  # This documentation
```

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose v2.0+
- 8GB+ RAM
- 25GB+ disk space
