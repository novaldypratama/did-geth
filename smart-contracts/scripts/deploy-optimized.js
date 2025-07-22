// deploy-simple.js - Simplified, robust deployment with extensive logging

const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("🚀 STARTING SIMPLE CONTRACT DEPLOYMENT");
  console.log("======================================");

  try {
    // Step 1: Get signer and basic info
    console.log("\n🔍 Step 1: Getting deployer information...");
    const [deployer] = await ethers.getSigners();
    const deployerAddress = await deployer.getAddress();
    const balance = await ethers.provider.getBalance(deployerAddress);

    console.log(`   Deployer: ${deployerAddress}`);
    console.log(`   Balance: ${ethers.formatEther(balance)} ETH`);

    if (balance === 0n) {
      throw new Error("Deployer has zero balance - cannot pay for gas");
    }

    // Step 2: Check network status
    console.log("\n🌐 Step 2: Checking network status...");
    const network = await ethers.provider.getNetwork();
    const blockNumber = await ethers.provider.getBlockNumber();

    console.log(`   Network: ${network.name} (Chain ID: ${network.chainId})`);
    console.log(`   Current block: ${blockNumber}`);

    if (blockNumber < 2) {
      console.log("   ⚠️  Network still initializing, waiting 10 seconds...");
      await new Promise(resolve => setTimeout(resolve, 10000));
    }

    // Step 3: Test basic transaction capability
    console.log("\n💨 Step 3: Testing transaction capability...");
    try {
      const gasPrice = await ethers.provider.getFeeData();
      console.log(`   Gas price: ${ethers.formatUnits(gasPrice.gasPrice || 1000000000n, "gwei")} gwei`);

      // Test gas estimation with simple transaction
      const simpleGas = await ethers.provider.estimateGas({
        to: deployerAddress,
        value: 0,
        data: "0x"
      });
      console.log(`   Gas estimation test: ${simpleGas} gas`);

    } catch (error) {
      console.log(`   ⚠️  Gas estimation test failed: ${error.message}`);
      // Continue anyway - this might work for contract deployment
    }

    // Step 4: Deploy RoleControl (first contract)
    console.log("\n🔐 Step 4: Deploying RoleControl...");
    const RoleControl = await ethers.getContractFactory("RoleControl");

    console.log("   📝 Contract factory created");
    console.log(`   📊 Bytecode size: ${RoleControl.bytecode.length / 2 - 1} bytes`);

    // Use simple deployment parameters
    const deploymentOptions = {
      gasLimit: 3000000,
      gasPrice: ethers.parseUnits("2", "gwei")
    };

    console.log("   🚀 Deploying with options:", deploymentOptions);
    console.log("   ⏳ This may take 30-60 seconds...");

    const roleControl = await RoleControl.deploy(deploymentOptions);
    console.log(`   📋 Transaction submitted: ${roleControl.deploymentTransaction().hash}`);

    // Wait for deployment
    console.log("   ⏳ Waiting for deployment confirmation...");
    await roleControl.waitForDeployment();
    const roleControlAddress = await roleControl.getAddress();

    console.log(`   ✅ RoleControl deployed at: ${roleControlAddress}`);

    // Get deployment receipt for cost analysis
    const receipt = await roleControl.deploymentTransaction().wait();
    const actualGas = receipt.gasUsed;
    const actualCost = actualGas * deploymentOptions.gasPrice;

    console.log(`   📊 Gas used: ${actualGas} (${((Number(actualGas) / deploymentOptions.gasLimit) * 100).toFixed(1)}% of limit)`);
    console.log(`   💰 Cost: ${ethers.formatEther(actualCost)} ETH`);

    // Step 5: Verify first contract
    console.log("\n✅ Step 5: Verifying RoleControl deployment...");
    const code = await ethers.provider.getCode(roleControlAddress);
    if (code === "0x") {
      throw new Error("RoleControl deployment failed - no code at address");
    }
    console.log(`   ✅ Contract verified: ${code.length / 2 - 1} bytes of code`);

    // Step 6: Deploy DidRegistry
    console.log("\n📋 Step 6: Deploying DidRegistry...");
    const DidRegistry = await ethers.getContractFactory("DidRegistry");

    console.log("   📝 Contract factory created");
    console.log(`   📊 Bytecode size: ${DidRegistry.bytecode.length / 2 - 1} bytes`);

    const didRegistry = await DidRegistry.deploy(roleControlAddress, deploymentOptions);
    console.log(`   📋 Transaction submitted: ${didRegistry.deploymentTransaction().hash}`);

    console.log("   ⏳ Waiting for deployment confirmation...");
    await didRegistry.waitForDeployment();
    const didRegistryAddress = await didRegistry.getAddress();

    console.log(`   ✅ DidRegistry deployed at: ${didRegistryAddress}`);

    // Step 7: Deploy CredentialRegistry
    console.log("\n🏆 Step 7: Deploying CredentialRegistry...");
    const CredentialRegistry = await ethers.getContractFactory("CredentialRegistry");

    console.log("   📝 Contract factory created");
    console.log(`   📊 Bytecode size: ${CredentialRegistry.bytecode.length / 2 - 1} bytes`);

    const credentialRegistry = await CredentialRegistry.deploy(
      roleControlAddress,
      didRegistryAddress,
      deploymentOptions
    );
    console.log(`   📋 Transaction submitted: ${credentialRegistry.deploymentTransaction().hash}`);

    console.log("   ⏳ Waiting for deployment confirmation...");
    await credentialRegistry.waitForDeployment();
    const credentialRegistryAddress = await credentialRegistry.getAddress();

    console.log(`   ✅ CredentialRegistry deployed at: ${credentialRegistryAddress}`);

    // Step 8: Final verification
    console.log("\n🔍 Step 8: Final verification...");
    const contracts = {
      RoleControl: roleControlAddress,
      DidRegistry: didRegistryAddress,
      CredentialRegistry: credentialRegistryAddress
    };

    for (const [name, address] of Object.entries(contracts)) {
      const contractCode = await ethers.provider.getCode(address);
      const isValid = contractCode !== "0x";
      console.log(`   ${name}: ${isValid ? '✅' : '❌'} ${address}`);

      if (!isValid) {
        throw new Error(`${name} deployment verification failed`);
      }
    }

    // Step 9: Save deployment info
    console.log("\n💾 Step 9: Saving deployment information...");

    const deploymentInfo = {
      network: {
        name: network.name || 'localhost',
        chainId: Number(network.chainId),
        blockNumber: await ethers.provider.getBlockNumber()
      },
      contracts,
      deployer: {
        address: deployerAddress,
        finalBalance: ethers.formatEther(await ethers.provider.getBalance(deployerAddress))
      },
      deployment: {
        timestamp: new Date().toISOString(),
        gasPrice: ethers.formatUnits(deploymentOptions.gasPrice, "gwei") + " gwei",
        totalContracts: Object.keys(contracts).length
      }
    };

    const filename = "deployment-info.json";
    fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
    console.log(`   ✅ Deployment info saved to: ${filename}`);

    // Success summary
    console.log("\n" + "🎉".repeat(20));
    console.log("🎉 DEPLOYMENT SUCCESSFUL! 🎉");
    console.log("🎉".repeat(20));

    console.log("\n📋 DEPLOYMENT SUMMARY:");
    console.log("=".repeat(40));
    Object.entries(contracts).forEach(([name, address]) => {
      console.log(`${name.padEnd(20)}: ${address}`);
    });
    console.log("=".repeat(40));

    console.log(`\n🎯 Next steps:`);
    console.log("   1. Assign roles: npx hardhat run scripts/assign-issuer-role.js --network localhost");
    console.log("   2. Assign roles: npx hardhat run scripts/assign-holder-role.js --network localhost");
    console.log("   3. Create DIDs: npx hardhat run scripts/web3signer-create-dids.js --network localhost");

    return contracts;

  } catch (error) {
    console.error("\n💥 DEPLOYMENT FAILED");
    console.error("====================");
    console.error(`Error: ${error.message}`);

    if (error.code) {
      console.error(`Error code: ${error.code}`);
    }

    if (error.reason) {
      console.error(`Reason: ${error.reason}`);
    }

    // Provide specific troubleshooting based on error type
    if (error.message.includes("insufficient funds")) {
      console.error("\n🔧 SOLUTION: Fund the deployer account with more ETH");
    } else if (error.message.includes("gas required exceeds allowance")) {
      console.error("\n🔧 SOLUTION: Increase gas limit in deployment options");
    } else if (error.message.includes("connection refused")) {
      console.error("\n🔧 SOLUTION: Check that Geth network is running on localhost:8545");
    } else if (error.message.includes("timeout")) {
      console.error("\n🔧 SOLUTION: Network may be slow, try again or increase timeouts");
    } else if (error.message.includes("nonce too low")) {
      console.error("\n🔧 SOLUTION: Reset account nonce or wait for pending transactions");
    }

    console.error("\n🔍 For detailed diagnostics, run:");
    console.error("   npx hardhat run scripts/network-diagnostic.js --network localhost");

    throw error;
  }
}

// Execute deployment
if (require.main === module) {
  main()
    .then(() => {
      console.log("\n✅ Deployment script completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("\n❌ Deployment script failed");
      process.exit(1);
    });
}

module.exports = main;
