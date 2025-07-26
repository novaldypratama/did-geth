'use strict';

/**
 * Class for managing simple account states.
 */
class SimpleState {
  /**
   * Initializes the instance.
   * @param {number} workerIndex 
   * @param {number} initialMoney 
   * @param {number} moneyToTransfer 
   * @param {number} accounts 
   */
  constructor(workerIndex, initialMoney, moneyToTransfer, accounts = 0) {
    this.accountsGenerated = accounts;
    this.initialMoney = initialMoney;
    this.moneyToTransfer = moneyToTransfer;
    this.accountPrefix = this._get26Num(workerIndex);
  }
}
