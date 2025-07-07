// create-dids-web3signer-fixed.js - Using direct HTTP requests to Web3Signer

const { ethers } = require("hardhat");
const fs = require('fs');
const axios = require('axios'); // npm install axios

// Web3Signer proxy URL
const WEB3SIGNER_URL = "http://127.0.0.1:18545";    // For transaction signing
const BESU_URL = "http://127.0.0.1:8545";           // For blockchain read operations

// Simple canonicalization function
function simpleCanonicalizeJSON(obj) {
  if (Array.isArray(obj)) {
    return '[' + obj.map(simpleCanonicalizeJSON).join(',') + ']';
  }

  if (obj && typeof obj === 'object') {
    return '{' + Object.keys(obj).sort().map(key => {
      return JSON.stringify(key) + ':' + simpleCanonicalizeJSON(obj[key]);
    }).join(',') + '}';
  }

  return JSON.stringify(obj);
}

async function createDidDocument(address) {
  const didId = `did:ethr:${address}`;

  const didDocument = {
    "@context": [
      "https://www.w3.org/ns/did/v1",
      "https://w3id.org/security/suites/ed25519-2020/v1"
    ],
    "id": didId,
    "verificationMethod": [
      {
        "id": `${didId}#keys-1`,
        "type": "Ed25519VerificationKey2020",
        "controller": didId,
        "publicKeyMultibase": "z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH"
      }
    ],
    "authentication": [
      `${didId}#keys-1`
    ],
    "service": [
      {
        "id": `${didId}#endpoint-1`,
        "type": "DIDCommMessaging",
        "serviceEndpoint": "https://example.com/endpoint/8377464"
      }
    ]
  };

  return didDocument;
}

async function canonicalizeAndHash(document) {
  const canonicalizedDoc = simpleCanonicalizeJSON(document);
  const docHash = ethers.keccak256(ethers.toUtf8Bytes(canonicalizedDoc));
  return { canonicalizedDoc, docHash };
}

// Send JSON-RPC request to Web3Signer (for transaction signing)
async function sendWeb3SignerRequest(method, params = []) {
  try {
    console.log(`Sending JSON-RPC request to Web3Signer: ${method} with params:`, params);

    const response = await axios({
      method: 'post',
      url: WEB3SIGNER_URL,
      headers: {
        'Content-Type': 'application/json'
      },
      data: JSON.stringify({
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: Math.floor(Math.random() * 10000) // Random ID for each request
      })
    });

    console.log(`Response from Web3Signer for ${method}:`, response.data);
    return response.data.result;
  } catch (error) {
    console.error(`Error in Web3Signer JSON-RPC request for ${method}:`, error.response?.data || error.message);
    throw error;
  }
}

// Send JSON-RPC request to Besu (for blockchain read operations)
async function sendBesuRequest(method, params = []) {
  try {
    console.log(`Sending JSON-RPC request to Besu: ${method} with params:`, params);

    const response = await axios({
      method: 'post',
      url: BESU_URL,
      headers: {
        'Content-Type': 'application/json'
      },
      data: JSON.stringify({
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: Math.floor(Math.random() * 10000) // Random ID for each request
      })
    });

    console.log(`Response from Besu for ${method}:`, response.data);
    return response.data.result;
  } catch (error) {
    console.error(`Error in Besu JSON-RPC request for ${method}:`, error.response?.data || error.message);
    throw error;
  }
}

// Get available accounts from Web3Signer
async function getWeb3SignerAccounts() {
  return await sendWeb3SignerRequest("eth_accounts");
}

// Use local hardhat node to get contract ABI
async function getContractAbi() {
  // Get the ABI from the hardhat artifacts
  const DidRegistry = await ethers.getContractFactory("DidRegistry");
  return DidRegistry.interface.formatJson();
}

// Encode function data for contract call
function encodeCreateDidFunction(contractAbi, address, docHash) {
  const iface = new ethers.Interface(contractAbi);
  return iface.encodeFunctionData("createDid", [address, docHash]);
}

// Send transaction through Web3Signer
async function sendTransaction(from, to, data) {
  // Get the current nonce for the sender (from Besu)
  const nonce = await sendBesuRequest("eth_getTransactionCount", [from, "latest"]);

  // Get current gas price (from Besu)
  const gasPrice = await sendBesuRequest("eth_gasPrice");

  // Estimate gas for the transaction (from Besu)
  const estimatedGas = await sendBesuRequest("eth_estimateGas", [{
    from: from,
    to: to,
    data: data
  }]);

  // Prepare transaction object
  const txObject = {
    from: from,
    to: to,
    gas: ethers.toQuantity(parseInt(estimatedGas, 16) * 1.5), // Add 50% buffer
    gasPrice: gasPrice,
    nonce: nonce,
    data: data
  };

  console.log("Sending transaction:", txObject);

  // Send the transaction via Web3Signer
  const txHash = await sendWeb3SignerRequest("eth_sendTransaction", [txObject]);
  console.log("Transaction hash:", txHash);

  // Wait for transaction receipt (using Besu)
  let receipt = null;
  let attempts = 0;

  while (!receipt && attempts < 30) {
    attempts++;
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
    receipt = await sendBesuRequest("eth_getTransactionReceipt", [txHash]);
    console.log(`Waiting for transaction confirmation... (attempt ${attempts})`);
  }

  if (!receipt) {
    throw new Error("Transaction confirmation timeout");
  }

  return { hash: txHash, receipt: receipt };
}

// Check if DID exists - FIXED to use Besu API instead of Web3Signer
async function checkDidExists(contractAddress, contractAbi, address) {
  const iface = new ethers.Interface(contractAbi);
  const data = iface.encodeFunctionData("didExists", [address]);

  // Use Besu API for eth_call
  const result = await sendBesuRequest("eth_call", [{
    to: contractAddress,
    data: data
  }, "latest"]);

  // Decode the boolean result
  return iface.decodeFunctionResult("didExists", result)[0];
}

async function main() {
  try {
    console.log("Starting DID creation using Web3Signer for signing and Besu for read operations...");

    console.log("Connecting to Web3Signer at:", WEB3SIGNER_URL);
    console.log("Connecting to Besu at:", BESU_URL);

    // Test connection to Web3Signer
    console.log("Testing connection to Web3Signer...");
    await sendWeb3SignerRequest("net_version");

    // Test connection to Besu
    console.log("Testing connection to Besu...");
    await sendBesuRequest("net_version");

    // Get available accounts from Web3Signer
    console.log("Fetching accounts from Web3Signer...");
    const accounts = await getWeb3SignerAccounts();
    console.log("Available accounts from Web3Signer:", accounts);

    // Select accounts for Issuer and Holder
    const issuerAddress = accounts[1]; // Using account at index 1 as Issuer
    const holderAddress = accounts[2]; // Using account at index 2 as Holder

    console.log("Selected Issuer address:", issuerAddress);
    console.log("Selected Holder address:", holderAddress);

    // Load the deployed DidRegistry contract
    // Replace with your actual deployed contract address
    const didRegistryAddress = "0xA5134e42CF382152894d040a0e89F2E4231062d8";
    console.log("DidRegistry contract address:", didRegistryAddress);

    // Get contract ABI
    const contractAbi = await getContractAbi();

    // ISSUER SECTION
    console.log("\n1. Creating DID for Issuer...");

    // Create Issuer DID document
    const issuerDidDoc = await createDidDocument(issuerAddress);
    console.log("Issuer DID document created");

    // Hash the document
    const { canonicalizedDoc: issuerCanonical, docHash: issuerDocHash } =
      await canonicalizeAndHash(issuerDidDoc);

    console.log("Generated docHash for Issuer:", issuerDocHash);

    // Save to file for reference
    fs.writeFileSync(
      `issuer-did-${issuerAddress.substring(0, 8)}.json`,
      JSON.stringify(issuerDidDoc, null, 2)
    );

    // Encode function call
    const issuerData = encodeCreateDidFunction(contractAbi, issuerAddress, issuerDocHash);

    // Send transaction from Issuer account
    console.log("\nIssuer creating DID on-chain through Web3Signer...");
    const issuerTx = await sendTransaction(issuerAddress, didRegistryAddress, issuerData);

    console.log("Issuer transaction confirmed!");
    console.log("Transaction hash:", issuerTx.hash);
    console.log("Block number:", parseInt(issuerTx.receipt.blockNumber, 16));

    // Verify DID was created
    const issuerDidExists = await checkDidExists(didRegistryAddress, contractAbi, issuerAddress);
    console.log("Issuer DID exists:", issuerDidExists);

    // HOLDER SECTION
    console.log("\n2. Creating DID for Holder...");

    // Create Holder DID document
    const holderDidDoc = await createDidDocument(holderAddress);
    console.log("Holder DID document created");

    // Hash the document
    const { canonicalizedDoc: holderCanonical, docHash: holderDocHash } =
      await canonicalizeAndHash(holderDidDoc);

    console.log("Generated docHash for Holder:", holderDocHash);

    // Save to file for reference
    fs.writeFileSync(
      `holder-did-${holderAddress.substring(0, 8)}.json`,
      JSON.stringify(holderDidDoc, null, 2)
    );

    // Encode function call
    const holderData = encodeCreateDidFunction(contractAbi, holderAddress, holderDocHash);

    // Send transaction from Holder account
    console.log("\nHolder creating DID on-chain through Web3Signer...");
    const holderTx = await sendTransaction(holderAddress, didRegistryAddress, holderData);

    console.log("Holder transaction confirmed!");
    console.log("Transaction hash:", holderTx.hash);
    console.log("Block number:", parseInt(holderTx.receipt.blockNumber, 16));

    // Verify DID was created
    const holderDidExists = await checkDidExists(didRegistryAddress, contractAbi, holderAddress);
    console.log("Holder DID exists:", holderDidExists);

    console.log("\n✅ DID creation through Web3Signer completed successfully!");

  } catch (error) {
    console.error("Error during DID creation:", error);
    process.exit(1);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
