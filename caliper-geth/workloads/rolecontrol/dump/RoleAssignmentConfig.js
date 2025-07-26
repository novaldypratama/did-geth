// RoleAssignmentConfig.js
/**
 * Role Assignment Strategy
 * Purpose: Business logic for generating role assignment scenarios
 * Pattern: Strategy Pattern for different assignment behaviors
 */

class RoleAssignmentStrategy {
  constructor(strategyType = 'balanced') {
    this.strategyType = strategyType;
    this.assignmentCounter = 0;

    // Role definitions based on RoleControl contract
    this.ROLES = {
      EMPTY: 0,
      ISSUER: 1,
      HOLDER: 2,
      TRUSTEE: 3
    };

    // Strategy configurations
    this.strategies = {
      'balanced': {
        weights: { ISSUER: 0.4, HOLDER: 0.5, TRUSTEE: 0.1 },
        description: 'Balanced role distribution'
      },
      'issuer-heavy': {
        weights: { ISSUER: 0.7, HOLDER: 0.25, TRUSTEE: 0.05 },
        description: 'Focus on issuer role assignments'
      },
      'holder-heavy': {
        weights: { ISSUER: 0.2, HOLDER: 0.75, TRUSTEE: 0.05 },
        description: 'Focus on holder role assignments'
      },
      'round-robin': {
        weights: { ISSUER: 0.33, HOLDER: 0.33, TRUSTEE: 0.33 },
        description: 'Round-robin role assignment'
      }
    };

    this.currentStrategy = this.strategies[strategyType] || this.strategies['balanced'];
    console.log(`🎯 Role assignment strategy: ${this.currentStrategy.description}`);
  }

  /**
   * Generate role assignment scenario based on strategy
   */
  generateAssignmentScenario() {
    const roleToAssign = this._selectRoleToAssign();
    const targetRole = this._determineTargetRole();

    this.assignmentCounter++;

    return {
      roleToAssign: roleToAssign,
      targetRole: targetRole,
      description: `Assign ${this._getRoleName(roleToAssign)} to ${targetRole} identity`,
      scenarioId: this.assignmentCounter
    };
  }

  /**
   * Select role to assign based on strategy weights
   */
  _selectRoleToAssign() {
    if (this.strategyType === 'round-robin') {
      return this._selectRoleRoundRobin();
    }

    return this._selectRoleWeighted();
  }

  /**
   * Weighted random selection
   */
  _selectRoleWeighted() {
    const random = Math.random();
    const weights = this.currentStrategy.weights;

    let cumulative = 0;

    if (random < (cumulative += weights.ISSUER)) {
      return this.ROLES.ISSUER;
    }
    if (random < (cumulative += weights.HOLDER)) {
      return this.ROLES.HOLDER;
    }
    if (random < (cumulative += weights.TRUSTEE)) {
      return this.ROLES.TRUSTEE;
    }

    // Fallback to HOLDER
    return this.ROLES.HOLDER;
  }

  /**
   * Round-robin selection
   */
  _selectRoleRoundRobin() {
    const roles = [this.ROLES.ISSUER, this.ROLES.HOLDER, this.ROLES.TRUSTEE];
    return roles[this.assignmentCounter % roles.length];
  }

  /**
   * Determine what type of identity should receive the role
   * Business Rule: Prefer assigning roles to identities that don't have them yet
   */
  _determineTargetRole() {
    // For benchmarking, we'll target various identity types
    const targetTypes = ['holder', 'issuer', 'unassigned'];
    return targetTypes[Math.floor(Math.random() * targetTypes.length)];
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

    return roleNames[roleValue] || 'UNKNOWN';
  }

  /**
   * Get strategy information
   */
  getStrategyName() {
    return this.strategyType;
  }

  /**
   * Get assignment statistics
   */
  getStatistics() {
    return {
      strategyType: this.strategyType,
      totalAssignments: this.assignmentCounter,
      currentWeights: this.currentStrategy.weights
    };
  }
}

module.exports = RoleAssignmentStrategy;
