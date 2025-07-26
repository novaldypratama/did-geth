// RoleControlWorkload.js
/**
 * RoleControl Workload Module
 * Purpose: Benchmark RoleControl.assignRole function performance
 * Architecture: Simple, focused, and fully Caliper-compliant
 */

const RoleAssignmentStrategy = require('./RoleAssignmentConfig');
const IdentityManager = require('./IdentityManager');
const ContractInteraction = require('./ContractInteraction');

class RoleControlWorkload {
  constructor() {
    this.identityManager = null;
    this.roleAssignmentStrategy = null;
    this.contractInteraction = null;
    this.isInitialized = false;
  }

  /**
   * CALIPER INTERFACE: Standard initialization method
   * Uses only connector.getContext() - no implementation details exposed
   */
  async initializeWorkload(networkInfo, context, args) {
    console.log('🚀 Initializing RoleControl workload module...');

    try {
      // Get available resources using standard Caliper interface
      const availableIdentities = await context.connector.getContext('identities');
      const availableContracts = await context.connector.getContext('contracts');

      // Validate RoleControl contract availability
      if (!availableContracts.includes('RoleControl')) {
        throw new Error('RoleControl contract not available in network configuration');
      }

      // Initialize modular components
      this.identityManager = new IdentityManager(availableIdentities);
      this.roleAssignmentStrategy = new RoleAssignmentStrategy(args?.strategy || 'balanced');
      this.contractInteraction = new ContractInteraction();

      // Validate initialization
      await this._validateSetup();

      this.isInitialized = true;
      console.log('✅ RoleControl workload initialized successfully');
      this._logInitializationSummary();

    } catch (error) {
      console.error('❌ RoleControl workload initialization failed:', error.message);
      throw error;
    }
  }

  /**
   * CALIPER INTERFACE: Standard transaction submission method
   * Returns properly formatted transaction request
   */
  async submitTransaction() {
    if (!this.isInitialized) {
      throw new Error('Workload not initialized. Call initializeWorkload() first.');
    }

    try {
      // Business logic: Generate role assignment scenario
      const assignmentScenario = this.roleAssignmentStrategy.generateAssignmentScenario();

      // Identity selection: Choose trustee and target
      const trusteeIdentity = this.identityManager.selectTrusteeIdentity();
      const targetIdentity = this.identityManager.selectTargetIdentity(assignmentScenario.targetRole);

      // Contract interaction: Build transaction request
      const transactionRequest = this.contractInteraction.buildAssignRoleTransaction({
        roleToAssign: assignmentScenario.roleToAssign,
        targetIdentity: targetIdentity,
        invokerIdentity: trusteeIdentity
      });

      console.log(`📝 Generated assignRole transaction: ${assignmentScenario.description}`);
      return transactionRequest;

    } catch (error) {
      console.error('❌ Transaction generation failed:', error.message);
      throw error;
    }
  }

  /**
   * CALIPER INTERFACE: Cleanup method
   */
  async cleanupWorkload() {
    console.log('🧹 Cleaning up RoleControl workload...');

    if (this.identityManager) {
      this.identityManager.cleanup();
    }

    this.isInitialized = false;
    console.log('✅ RoleControl workload cleanup completed');
  }

  /**
   * Validation: Ensure proper setup
   */
  async _validateSetup() {
    // Validate trustee availability
    if (!this.identityManager.hasTrusteeIdentities()) {
      throw new Error('No trustee identities available for role assignment');
    }

    // Validate target identities
    if (!this.identityManager.hasTargetIdentities()) {
      throw new Error('No target identities available for role assignment');
    }

    console.log('✅ Setup validation passed');
  }

  /**
   * Logging: Initialization summary
   */
  _logInitializationSummary() {
    const summary = this.identityManager.getSummary();
    console.log('📊 Workload Configuration:');
    console.log(`   Available Trustees: ${summary.trusteeCount}`);
    console.log(`   Available Targets: ${summary.targetCount}`);
    console.log(`   Assignment Strategy: ${this.roleAssignmentStrategy.getStrategyName()}`);
    console.log(`   Total Identities: ${summary.totalCount}`);
  }
}

module.exports = RoleControlWorkload;
