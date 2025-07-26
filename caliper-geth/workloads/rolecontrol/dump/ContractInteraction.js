// ContractInteraction.js
/**
 * Contract Interaction Handler
 * Purpose: Build RoleControl contract transaction requests
 * Architecture: Pure transaction request builder - no blockchain calls
 */

class ContractInteraction {
  constructor() {
    // RoleControl contract role definitions
    this.ROLES = {
      EMPTY: 0,
      ISSUER: 1,
      HOLDER: 2,
      TRUSTEE: 3
    };

    console.log('📝 Contract Interaction handler initialized');
  }

  /**
   * Build assignRole transaction request
   * Returns standard Caliper transaction request format
   */
  buildAssignRoleTransaction({ roleToAssign, targetIdentity, invokerIdentity }) {
    // Validate inputs
    this._validateRoleValue(roleToAssign);
    this._validateIdentityHandle(targetIdentity);
    this._validateIdentityHandle(invokerIdentity);

    // Get target address from identity handle
    const targetAddress = this._getAddressFromHandle(targetIdentity);

    // Build transaction request following Caliper standards
    const transactionRequest = {
      contractId: 'RoleControl',
      contractFunction: 'assignRole',
      contractArguments: [
        roleToAssign,    // uint8 role value
        targetAddress    // address account
      ],
      invokerIdentity: invokerIdentity,  // Text-based identity handle
      readOnly: false,                   // This is a state-changing transaction
      timeout: 30000                     // 30 second timeout
    };

    console.log(`🔨 Built assignRole transaction: role=${this._getRoleName(roleToAssign)}, target=${targetIdentity}`);

    return transactionRequest;
  }

  /**
   * Build revokeRole transaction request (for future use)
   */
  buildRevokeRoleTransaction({ roleToRevoke, targetIdentity, invokerIdentity }) {
    this._validateRoleValue(roleToRevoke);
    this._validateIdentityHandle(targetIdentity);
    this._validateIdentityHandle(invokerIdentity);

    const targetAddress = this._getAddressFromHandle(targetIdentity);

    return {
      contractId: 'RoleControl',
      contractFunction: 'revokeRole',
      contractArguments: [
        roleToRevoke,
        targetAddress
      ],
      invokerIdentity: invokerIdentity,
      readOnly: false,
      timeout: 30000
    };
  }

  /**
   * Build hasRole query request (read-only)
   */
  buildHasRoleQuery({ role, targetIdentity }) {
    this._validateRoleValue(role);
    this._validateIdentityHandle(targetIdentity);

    const targetAddress = this._getAddressFromHandle(targetIdentity);

    return {
      contractId: 'RoleControl',
      contractFunction: 'hasRole',
      contractArguments: [
        role,
        targetAddress
      ],
      readOnly: true,  // This is a view function
      timeout: 10000   // Shorter timeout for reads
    };
  }

  /**
   * Validation helpers
   */
  _validateRoleValue(role) {
    const validRoles = Object.values(this.ROLES);
    if (!validRoles.includes(role)) {
      throw new Error(`Invalid role value: ${role}. Valid roles: ${validRoles.join(', ')}`);
    }
  }

  _validateIdentityHandle(identityHandle) {
    if (!identityHandle || typeof identityHandle !== 'string') {
      throw new Error(`Invalid identity handle: ${identityHandle}`);
    }

    if (!identityHandle.startsWith('identity-')) {
      throw new Error(`Identity handle must start with 'identity-': ${identityHandle}`);
    }
  }

  /**
   * Convert identity handle to Ethereum address
   * Note: Simplified for testing - production version would use proper mapping
   */
  _getAddressFromHandle(identityHandle) {
    const match = identityHandle.match(/identity-(\d+)/);
    if (!match) {
      throw new Error(`Invalid identity handle format: ${identityHandle}`);
    }

    const index = parseInt(match[1]);
    // Generate deterministic address for testing
    return `0x${(index + 1).toString(16).padStart(40, '0')}`;
  }

  /**
   * Get human-readable role name
   */
  _getRoleName(roleValue) {
    const roleNames = {
      [this.ROLES.EMPTY]: 'EMPTY',
      [this.ROLES.ISSUER]: 'ISSUER',
      [this.ROLES.HOLDER]: 'HOLDER',
      [this.ROLES.TRUSTEE]: 'TRUSTEE'
    };

    return roleNames[roleValue] || `UNKNOWN(${roleValue})`;
  }

  /**
   * Get role value from name (utility function)
   */
  getRoleValue(roleName) {
    const upperRoleName = roleName.toUpperCase();
    return this.ROLES[upperRoleName] ?? null;
  }

  /**
   * Get all available roles
   */
  getAvailableRoles() {
    return { ...this.ROLES };
  }
}

module.exports = ContractInteraction;
