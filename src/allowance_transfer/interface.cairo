use starknet::ContractAddress;
use starknet::storage_access::StorePacking;

pub mod events {
    use starknet::ContractAddress;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum AllowanceTransferEvent {
        NonceInvalidation: NonceInvalidation,
        Approval: Approval,
        Permit: Permit,
        Lockdown: Lockdown,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NonceInvalidation {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        /// NOTE: in solidity uint48
        pub new_nonce: u64,
        pub old_nonce: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        /// NOTE: uint160 in sol
        pub amount: u256,
        pub expiration: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Permit {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        /// NOTE: uint160 in sol
        pub amount: u256,
        pub expiration: u64,
        pub nonce: u64,
    }


    #[derive(Drop, starknet::Event)]
    pub struct Lockdown {
        #[key]
        pub owner: ContractAddress,
        pub token: ContractAddress,
        pub spender: ContractAddress,
    }
}

#[derive(Drop, Copy, Serde, Hash)]
pub struct PermitDetails {
    pub token: ContractAddress,
    pub amount: u256,
    pub expiration: u64,
    pub nonce: u64,
}

#[derive(Drop, Copy, Serde, Hash)]
pub struct PermitSingle {
    pub details: PermitDetails,
    pub spender: ContractAddress,
    pub sig_deadline: u256,
}

#[derive(Drop, Copy, Serde)]
pub struct PermitBatch {
    pub details: Span<PermitDetails>,
    pub spender: ContractAddress,
    pub sig_deadline: u256,
}

/// NOTE: in solidity this pack u160 + 2 * u48 into u256
#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub struct Allowance {
    pub amount: u256,
    pub expiration: u64,
    pub nonce: u64,
}

impl AllowancePacking of StorePacking<Allowance, (u256, u64, u64)> {
    fn pack(value: Allowance) -> (u256, u64, u64) {
        (value.amount, value.expiration, value.nonce)
    }

    fn unpack(value: (u256, u64, u64)) -> Allowance {
        let (amount, expiration, nonce) = value;
        Allowance { amount, expiration, nonce }
    }
}

#[derive(Drop, Copy, Serde)]
pub struct TokenSpenderPair {
    pub token: ContractAddress,
    pub spender: ContractAddress,
}

#[derive(Drop, Copy, Serde)]
pub struct AllowanceTransferDetails {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub amount: u256,
    pub token: ContractAddress,
}

/// Implements IEIP712
#[starknet::interface]
pub trait IAllowanceTransfer<TState> {
    fn allowance(
        self: @TState, user: ContractAddress, token: ContractAddress, spender: ContractAddress,
    ) -> (u256, u64, u64);
    fn approve(
        ref self: TState,
        token: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
    );
    fn permit(
        ref self: TState,
        owner: ContractAddress,
        permit_single: PermitSingle,
        signature: Array<felt252>,
    );
    fn permit_batch(
        ref self: TState,
        owner: ContractAddress,
        permit_batch: PermitBatch,
        signature: Array<felt252>,
    );
    fn transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    );
    fn batch_transfer_from(ref self: TState, transfer_details: Array<AllowanceTransferDetails>);
    fn lockdown(ref self: TState, approvals: Array<TokenSpenderPair>);
    fn invalidate_nonces(
        ref self: TState, token: ContractAddress, spender: ContractAddress, new_nonce: u64,
    );
}
