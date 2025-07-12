use starknet::ContractAddress;

/// ERRORS ///

pub mod errors {
    pub const SignatureExpired: felt252 = 'ST: signature expired';
    pub const LengthMismatch: felt252 = 'ST: length mismatch';
    pub const InvalidSignature: felt252 = 'ST: invalid signature';
    pub const InvalidAmount: felt252 = 'ST: invalid amount';
}

/// STRUCTS ///

/// The token and amount details for a transfer signed in the permit transfer signature
/// @param token The ERC20 token address
/// @param amount The maximum amount that can be spent
#[derive(Drop, Copy, Hash, Serde)]
pub struct TokenPermissions {
    pub token: ContractAddress,
    pub amount: u256,
}

/// The signed permit message for a single token transfer
/// @dev Do not need to pass in spender address as it is required that it is msg.sender
/// @dev A user still signs over a spender address (spender is located between `permitted` &
/// `nonce`)
/// @param permitted The token permissions for the transfer
/// @param nonce The (unordered) nonce used to prevent replay attacks
/// @param deadline The timestamp after which the permit is no longer valid
#[derive(Drop, Copy, Hash, Serde)]
pub struct PermitTransferFrom {
    pub permitted: TokenPermissions,
    pub nonce: felt252,
    pub deadline: u256,
}

/// The signed permit message for a batch token transfer
/// @dev The same `spender` rules apply as for `PermitTransferFrom`
/// @param permitted The token permissions for each transfer
/// @param nonce The (unordered) nonce used to prevent replay attacks
/// @param deadline The timestamp after which the permit is no longer valid
#[derive(Drop, Copy, Serde)]
pub struct PermitBatchTransferFrom {
    pub permitted: Span<TokenPermissions>,
    pub nonce: felt252,
    pub deadline: u256,
}

/// Specifies the recipient address and amount for each transfer
/// @param to The recipient address for the transfer
/// @param requested_amount The amount requested to be transferred by the spender
#[derive(Drop, Copy, Hash, Serde)]
pub struct SignatureTransferDetails {
    pub to: ContractAddress,
    pub requested_amount: u256,
}

/// INTERFACE ///

#[starknet::interface]
pub trait ISignatureTransfer<TState> {
    /// Transfers a token using a signed permit message
    /// @dev Reverts if the requested amount is greater than the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transfer_details The spender's requested transfer details for the permitted token
    /// @param signature The signature to verify
    fn permit_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
        owner: ContractAddress,
        signature: Array<felt252>,
    );

    /// Transfers multiple tokens using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transfer_details Specifies the recipient and requested amount for the token transfer
    /// @param signature The signature to verify
    fn permit_batch_transfer_from(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        signature: Array<felt252>,
    );

    /// Transfers a token using a signed permit message, including extra data to verify the
    /// signature over
    /// @dev The witness type string must follow snip-12 ordering of nested structs
    /// and must include the TokenPermissions & u256 type definitions
    /// @dev Reverts if the requested amount is greater than
    /// the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transfer_details The spender's requested transfer details for the permitted token
    /// @param witness Extra data to include when checking the user signature (struct hash of
    /// witness struct)
    /// @param witness_type_string The snip-12 type definition for remaining string stub of the
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

    /// Transfers multiple tokens using a signed permit message, including extra data to verify the
    /// signature over
    /// @dev The witness type string must follow snip-12 ordering of nested structs and must include
    /// the TokenPermissions & u256 type definitions
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transfer_details Specifies the recipient and requested amount for the token transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witness_type_string The EIP-712 type definition for remaining string stub of the
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
