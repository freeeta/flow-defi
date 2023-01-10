import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import StakedFlowToken from "./StakedFlowToken.cdc";

// import FungibleToken from 0x9a0766d93b6608b7
// import FlowToken from 0x7e60df042a9c0868

import Crypto

pub contract StakedFlowPool {

    // Event that is emitted when Flow tokens are locked in the StakedFlowPool vault
    //event Lock(address indexed asset, address indexed sender, string chain, bytes32 indexed recipient, uint amount);
    pub event Lock(recipient: Address?, amount: UFix64)

    // Event that is emitted when tokens are unlocked by Gateway
    pub event Unlock(account: Address, amount: UFix64)

    // Event that is emitted when locked Flow tokens are withdrawn
    pub event TokensWithdrawn(amount: UFix64)

    // Private vault with public deposit function
    access(self) var vault: @FlowToken.Vault

    // Supply cap for Flow tokens
    access(self) var flowTokenSupplyCap: UFix64

    // Amount of pre-minted staked tokens that allow to unlock flow tokens
    access(self) var stakedFlowTokenSupply: UFix64

    // Private vault for staked tokens
    access(self) var stakedFlowTokenVault: @StakedFlowToken.Vault

    /// This interface for locking Flow tokens.
    pub resource interface FlowLock {
        pub fun lock(from: @FungibleToken.Vault): @FungibleToken.Vault
    }

    pub resource StakedFlowPoolParticipant: FlowLock {

        pub fun lock(from: @FungibleToken.Vault): @FungibleToken.Vault {
            pre {
                // StakedFlowPool.vault.balance <= StakedFlowPool.supplyCaps["FLOW"]: "Supply Cap Exceeded"
                StakedFlowPool.vault.balance + from.balance <= StakedFlowPool.flowTokenSupplyCap: "Supply Cap Exceeded"
            }
            let from <- from as! @FlowToken.Vault
            let balance = from.balance
            StakedFlowPool.vault.deposit(from: <-from)

            let vault <- StakedFlowPool.stakedFlowTokenVault.withdraw(amount: StakedFlowPool.getStakedFlowTokenAmount(amount: balance))

            emit Lock(recipient: self.owner?.address, amount: balance);
            return <-vault
        }

        pub fun unlock(from: @StakedFlowToken.Vault): @FungibleToken.Vault {
            let from <- from as! @StakedFlowToken.Vault
            let balance = from.balance

            StakedFlowPool.stakedFlowTokenVault.deposit(from: <-from)

            let vault <- StakedFlowPool.vault.withdraw(amount: balance)

            emit TokensWithdrawn(amount: balance)

            return <-vault
        }
    }

    pub resource Administrator {
        // withdraw
        // Allows the administrator to withdraw locked Flow tokens
        pub fun withdrawLockedFlowTokens(amount: UFix64): @FungibleToken.Vault {
            let vault <- StakedFlowPool.vault.withdraw(amount: amount)
            emit TokensWithdrawn(amount: amount)
            return <-vault
        }

        // Unlock
        //
        // Allows the administrator to unlock Flow tokens
        pub fun unlock(toAddress: Address, amount: UFix64) {
            // Get capability to deposit tokens to `toAddress` receiver
            let toAddressReceiver = getAccount(toAddress)
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
                .borrow() ?? panic("Could not borrow FLOW receiver capability")

            // Withdraw Flow tokens to the temporary vault
            let temporaryVault <- StakedFlowPool.vault.withdraw(amount: amount)

            // Deposit Flow tokens to receiver from the temporary vault
            toAddressReceiver.deposit(from: <-temporaryVault)

            // Emit event
            emit Unlock(account: toAddress, amount: amount)
        }
    }

    pub fun createStakedFlowPoolParticipant(): @StakedFlowPoolParticipant {
        return <- create StakedFlowPoolParticipant()
    }

    pub fun getLockedBalance(): UFix64 {
        return self.vault.balance
    }

    pub fun getStakedFlowTokenAmount(amount: UFix64): UFix64 {
        return amount * self.stakedFlowTokenSupply / self.flowTokenSupplyCap
    }

    pub fun getFlowTokenAmountToWithdraw(amount: UFix64): UFix64 {
        return amount * self.flowTokenSupplyCap / self.stakedFlowTokenSupply
    }

    init() {
        // Set intitial values
        self.flowTokenSupplyCap = 1000000.0
        self.stakedFlowTokenSupply = self.flowTokenSupplyCap

        // Create a new pool Vault and save it in storage
        self.vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        // Create a new Admin resource
        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/admin)

        // Create a new staked pool Vault and mint tokens to it
        let tokenAdmin = self.account.borrow<&StakedFlowToken.Administrator>(from: StakedFlowToken.AdminStoragePath)
            ?? panic("Signer is not the token admin")
        let stakedFlowTokenMinter <- tokenAdmin.createNewMinter()
        self.stakedFlowTokenVault <- stakedFlowTokenMinter.mintTokens(amount: self.stakedFlowTokenSupply)

        destroy stakedFlowTokenMinter
    }
}