use starknet::ContractAddress;
use starknet::storage_access::StorePacking;


/// ERRORS ///
pub mod errors {
    pub const SignatureExpired: felt252 = 'AT: signature expired';
    pub const AllowanceExpired: felt252 = 'AT: allowance expired';
    pub const InvalidNonce: felt252 = 'AT: invalid nonce';
    pub const InvalidSignature: felt252 = 'AT: invalid signature';
    pub const ExcessiveNonceDelta: felt252 = 'AT: excessive nonce delta';
    //    pub const InvalidSignature: felt252 = 'AT: invalid signature';
//    pub const NonceTooHigh: felt252 = 'AT: nonce too high';
//    pub const NonceTooLow: felt252 = 'AT: nonce too low';
//    pub const TooManyNoncesInvalidated: felt252 = 'AT: too many nonces invalidated';
}

/// EVENTS ///
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

    /// @notice Emits an event when the owner successfully invalidates an ordered nonce.
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


    /// @notice Emits an event when the owner successfully sets permissions on a token for the
    /// spender.
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

    /// @notice Emits an event when the owner successfully sets permissions using a permit
    /// signature on a token for the spender.
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

    /// @notice Emits an event when the owner sets the allowance back to 0 with the lockdown
    /// function.
    #[derive(starknet::Event, Drop)]
    pub struct Lockdown {
        #[key]
        pub owner: ContractAddress,
        pub token: ContractAddress,
        pub spender: ContractAddress,
    }
}

/// STRUCTS ///

/// @notice The permit data for a token
#[derive(Drop, Copy, Serde, Hash)]
pub struct PermitDetails {
    // ERC20 token address
    pub token: ContractAddress,
    // the maximum amount allowed to spend
    pub amount: u256,
    // timestamp at which a spender's token allowances become invalid
    pub expiration: u64,
    // an incrementing value indexed per owner,token,and spender for each signature
    pub nonce: u64,
}

/// @notice The permit message signed for a single token allowance
#[derive(Drop, Copy, Serde, Hash)]
pub struct PermitSingle {
    // the permit data for a single token allowance
    pub details: PermitDetails,
    // address permissioned on the allowed tokens
    pub spender: ContractAddress,
    // deadline on the permit signature
    pub sig_deadline: u256,
}

/// @notice The permit message signed for multiple token allowances
#[derive(Drop, Copy, Serde)]
pub struct PermitBatch {
    // the permit data for multiple token allowances
    pub details: Span<PermitDetails>,
    // address permissioned on the allowed tokens
    pub spender: ContractAddress,
    // deadline on the permit signature
    pub sig_deadline: u256,
}

/// @notice The saved permissions
/// @dev This info is saved per owner, per token, per spender and all signed over in the permit
/// message @dev Setting amount to type(uint160).max sets an unlimited approval
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

/// @notice A token spender pair.
#[derive(Copy, Drop, Serde)]
pub struct TokenSpenderPair {
    // the token the spender is approved
    pub token: ContractAddress,
    // the spender address
    pub spender: ContractAddress,
}

/// @notice Details for a token transfer.
#[derive(Copy, Drop, Serde)]
pub struct AllowanceTransferDetails {
    // the owner of the token
    pub from: ContractAddress,
    // the recipient of the token
    pub to: ContractAddress,
    // the amount of the token
    pub amount: u256,
    // the token to be transferred
    pub token: ContractAddress,
}

/// INTERFACE ///

/// Implements IEIP712
#[starknet::interface]
pub trait IAllowanceTransfer<TState> {
    /// Reads ///

    /// @notice A mapping from owner address to token address to spender address to PackedAllowance
    /// struct, which contains details and conditions of the approval.
    /// @notice The mapping is indexed in the above order see:
    /// allowance[ownerAddress][tokenAddress][spenderAddress]
    /// @dev The packed slot holds the allowed amount, expiration at which the allowed amount is no
    /// longer valid, and current nonce thats updated on any signature based approvals.
    fn allowance(
        self: @TState, user: ContractAddress, token: ContractAddress, spender: ContractAddress,
    ) -> (u256, u64, u64);


    /// Writes ///

    /// @notice Approves the spender to use up to amount of the specified token up until the
    /// expiration @param token The token to approve
    /// @param spender The spender address to approve
    /// @param amount The approved amount of the token
    /// @param expiration The timestamp at which the approval is no longer valid
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve
    /// @dev Setting amount to type(uint160).max sets an unlimited approval
    fn approve(
        ref self: TState,
        token: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
    );

    /// @notice Permit a spender to a given amount of the owners token via the owner's EIP-712
    /// signature @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitSingle Data signed over by the owner specifying the terms of approval
    /// @param TState The owner's signature over the permit data
    fn permit(
        ref self: TState,
        owner: ContractAddress,
        permit_single: PermitSingle,
        signature: Array<felt252>,
    );

    /// @notice Permit a spender to the signed amounts of the owners tokens via the owner's EIP-712
    /// signature @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitBatch Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    fn permit_batch(
        ref self: TState,
        owner: ContractAddress,
        permit_batch: PermitBatch,
        signature: Array<felt252>,
    );

    /// @notice Transfer approved tokens from one address to another
    /// @param from The address to transfer from
    /// @param to The address of the recipient
    /// @param amount The amount of the token to transfer
    /// @param token The token address to transfer
    /// @dev Requires the from address to have approved at least the desired amount
    /// of tokens to msg.sender.
    fn transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    );

    /// @notice Transfer approved tokens in a batch
    /// @param transferDetails Array of owners, recipients, amounts, and tokens for the transfers
    /// @dev Requires the from addresses to have approved at least the desired amount
    /// of tokens to msg.sender.
    fn batch_transfer_from(ref self: TState, transfer_details: Array<AllowanceTransferDetails>);

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals
    /// @param approvals Array of approvals to revoke.
    fn lockdown(ref self: TState, approvals: Array<TokenSpenderPair>);

    /// @notice Invalidate nonces for a given (token, spender) pair
    /// @param token The token to invalidate nonces for
    /// @param spender The spender to invalidate nonces for
    /// @param newNonce The new nonce to set. Invalidates all nonces less than it.
    /// @dev Can't invalidate more than 2**16 nonces per transaction.
    fn invalidate_nonces(
        ref self: TState, token: ContractAddress, spender: ContractAddress, new_nonce: u64,
    );
}
