use starknet::ContractAddress;

/// ERRORS ///

pub mod errors {
    pub const SignatureExpired: felt252 = 'ST: signature expired';
    pub const LengthMismatch: felt252 = 'ST: length mismatch';
    pub const InvalidSignature: felt252 = 'ST: invalid signature';
    pub const InvalidAmount: felt252 = 'ST: invalid amount';
}

/// EVENTS ///

pub mod events {
    #[event]
    #[derive(starknet::Event, Drop)]
    pub enum SignatureTransferEvent {
        UnorderedNonceInvalidation: UnorderedNonceInvalidation,
    }

    /// @notice Emits an event when the owner successfully invalidates an unordered nonce.
    #[derive(Drop, starknet::Event)]
    pub struct UnorderedNonceInvalidation {
        #[key]
        owner: starknet::ContractAddress,
        word: u256,
        mask: u256,
    }
}

/// STRUCTS ///

/// @notice The token and amount details for a transfer signed in the permit transfer signature
#[derive(Drop, Copy, Hash, Serde)]
pub struct TokenPermissions {
    // ERC20 token address
    pub token: ContractAddress,
    // the maximum amount that can be spent
    pub amount: u256,
}

/// @notice The signed permit message for a single token transfer
/// NOTE: spender is caller between `permitted` & `nonce` in /snip12_utils.cairo
#[derive(Drop, Copy, Hash, Serde)]
pub struct PermitTransferFrom {
    pub permitted: TokenPermissions,
    // a unique value for every token owner's signature to prevent signature replays
    pub nonce: felt252,
    // deadline on the permit signature
    pub deadline: u256,
}

/// @notice Used to reconstruct the signed permit message for multiple token transfers
/// @dev Do not need to pass in spender address as it is required that it is msg.sender
/// @dev Note that a user still signs over a spender address
/// NOTE: spender is caller between `permitted` & `nonce` in /snip12_utils.cairo
#[derive(Drop, Copy, Serde)]
pub struct PermitBatchTransferFrom {
    // the tokens and corresponding amounts permitted for a transfer
    pub permitted: Span<TokenPermissions>,
    // a unique value for every token owner's signature to prevent signature replays
    pub nonce: felt252,
    // deadline on the permit signature
    pub deadline: u256,
}

/// @notice Specifies the recipient address and amount for batched transfers.
/// @dev Recipients and amounts correspond to the index of the signed token permissions array.
/// @dev Reverts if the requested amount is greater than the permitted signed amount.
#[derive(Drop, Copy, Hash, Serde)]
pub struct SignatureTransferDetails {
    // recipient address
    pub to: ContractAddress,
    // spender requested amount
    pub requested_amount: u256,
}

/// INTERFACE ///

#[starknet::interface]
pub trait ISignatureTransfer<TState> {
    /// Writes ///

    /// @notice Transfers a token using a signed permit message
    /// @dev Reverts if the requested amount is greater than the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param signature The signature to verify
    fn permit_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
        owner: ContractAddress,
        signature: Array<felt252>,
    );

    /// @notice Transfers multiple tokens using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param signature The signature to verify
    fn permit_batch_transfer_from(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        signature: Array<felt252>,
    );

    /// @notice Transfers a token using a signed permit message
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include
    /// the TokenPermissions type definition
    /// @dev Reverts if the requested amount is greater than
    /// the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the
    /// typehash
    /// @param signature The signature to verify
    fn permit_witness_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
        owner: ContractAddress,
        witness: felt252,
        witness_type_string: ByteArray,
        signature: Array<felt252>,
    );

    /// @notice Transfers multiple tokens using a signed permit message
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include
    /// the TokenPermissions type definition @notice Includes extra data provided by the caller to
    /// verify signature over @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the
    /// typehash
    /// @param signature The signature to verify
    fn permit_witness_batch_transfer_from(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        witness: felt252,
        witness_type_string: ByteArray,
        signature: Array<felt252>,
    );
}
