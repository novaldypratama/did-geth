// IdentityManager.js
/**
 * Identity Manager
 * Purpose: Manage identity selection and classification
 * Architecture: Pure business logic, no connector dependencies
 */

class IdentityManager {
  constructor(availableIdentities) {
    this.allIdentities = availableIdentities || [];
    this.identityClassification = this._classifyIdentities();

    console.log('👥 Identity Manager initialized');
    this._logIdentityClassification();
  }

  /**
   * Classify identities based on handle patterns
   * Business Rule: identity-0 = trustee, others distributed
   */
  _classifyIdentities() {
    const classification = {
      trustees: [],
      issuers: [],
      holders: [],
      unassigned: []
    };

    for (const identityHandle of this.allIdentities) {
      const index = this._extractIndexFromHandle(identityHandle);

      if (index === 0) {
        // First identity is always trustee
        classification.trustees.push(identityHandle);
      } else if (index % 3 === 1) {
        // Every 3rd identity starting from 1 is issuer
        classification.issuers.push(identityHandle);
      } else if (index % 3 === 2) {
        // Every 3rd identity starting from 2 is holder
        classification.holders.push(identityHandle);
      } else {
        // Remaining identities are unassigned
        classification.unassigned.push(identityHandle);
      }
    }

    return classification;
  }

  /**
   * Extract numeric index from identity handle
   */
  _extractIndexFromHandle(handle) {
    const match = handle.match(/identity-(\d+)/);
    return match ? parseInt(match[1]) : 0;
  }

  /**
   * Select a trustee identity for invoking assignRole
   * Business Rule: Only trustees can assign roles
   */
  selectTrusteeIdentity() {
    if (this.identityClassification.trustees.length === 0) {
      throw new Error('No trustee identities available');
    }

    // For simplicity, use the first trustee
    // In production, you might implement round-robin or random selection
    const selectedTrustee = this.identityClassification.trustees[0];

    console.log(`👑 Selected trustee: ${selectedTrustee}`);
    return selectedTrustee;
  }

  /**
   * Select target identity for role assignment
   */
  selectTargetIdentity(preferredTargetType = 'any') {
    let candidatePool = [];

    switch (preferredTargetType) {
      case 'holder':
        candidatePool = this.identityClassification.holders;
        break;
      case 'issuer':
        candidatePool = this.identityClassification.issuers;
        break;
      case 'unassigned':
        candidatePool = this.identityClassification.unassigned;
        break;
      default:
        // 'any' - select from all non-trustee identities
        candidatePool = [
          ...this.identityClassification.issuers,
          ...this.identityClassification.holders,
          ...this.identityClassification.unassigned
        ];
    }

    if (candidatePool.length === 0) {
      // Fallback to any available identity except trustees
      candidatePool = this.allIdentities.filter(
        identity => !this.identityClassification.trustees.includes(identity)
      );
    }

    if (candidatePool.length === 0) {
      throw new Error('No suitable target identities available');
    }

    const selectedTarget = candidatePool[Math.floor(Math.random() * candidatePool.length)];
    console.log(`🎯 Selected target: ${selectedTarget} (type: ${preferredTargetType})`);

    return selectedTarget;
  }

  /**
   * Validation methods
   */
  hasTrusteeIdentities() {
    return this.identityClassification.trustees.length > 0;
  }

  hasTargetIdentities() {
    const targetCount = this.identityClassification.issuers.length +
      this.identityClassification.holders.length +
      this.identityClassification.unassigned.length;
    return targetCount > 0;
  }

  /**
   * Get summary information
   */
  getSummary() {
    return {
      totalCount: this.allIdentities.length,
      trusteeCount: this.identityClassification.trustees.length,
      issuerCount: this.identityClassification.issuers.length,
      holderCount: this.identityClassification.holders.length,
      unassignedCount: this.identityClassification.unassigned.length,
      targetCount: this.identityClassification.issuers.length +
        this.identityClassification.holders.length +
        this.identityClassification.unassigned.length
    };
  }

  /**
   * Cleanup resources
   */
  cleanup() {
    console.log('🧹 Identity Manager cleanup completed');
  }

  /**
   * Convert identity handle to address (for contract calls)
   * Note: This is simplified for testing - real implementation would
   * get actual addresses from the connector context
   */
  getAddressFromHandle(identityHandle) {
    const index = this._extractIndexFromHandle(identityHandle);
    // Generate deterministic test address
    return `0x${(index + 1).toString(16).padStart(40, '0')}`;
  }

  /**
   * Logging helper
   */
  _logIdentityClassification() {
    const summary = this.getSummary();
    console.log('📊 Identity Classification:');
    console.log(`   Trustees: ${summary.trusteeCount} (${this.identityClassification.trustees.join(', ')})`);
    console.log(`   Issuers: ${summary.issuerCount} (${this.identityClassification.issuers.slice(0, 3).join(', ')}${summary.issuerCount > 3 ? '...' : ''})`);
    console.log(`   Holders: ${summary.holderCount} (${this.identityClassification.holders.slice(0, 3).join(', ')}${summary.holderCount > 3 ? '...' : ''})`);
    console.log(`   Unassigned: ${summary.unassignedCount}`);
  }
}

module.exports = IdentityManager;
