// ISignatureTransfer.cairo
use starknet::ContractAddress;

/// @notice The token and amount details for a transfer signed in the permit transfer signature
#[derive(Drop, Serde)]
pub struct TokenPermissions {
    // ERC20 token address
    pub token: ContractAddress,
    // the maximum amount that can be spent
    pub amount: u256,
}

/// @notice The signed permit message for a single token transfer
#[derive(Drop, Serde)]
pub struct PermitTransferFrom {
    pub permitted: TokenPermissions,
    // a unique value for every token owner's signature to prevent signature replays
    pub nonce: u256,
    // deadline on the permit signature
    pub deadline: u256,
}

/// @notice Specifies the recipient address and amount for batched transfers.
/// @dev Recipients and amounts correspond to the index of the signed token permissions array.
/// @dev Reverts if the requested amount is greater than the permitted signed amount.
#[derive(Drop, Serde)]
pub struct SignatureTransferDetails {
    // recipient address
    pub to: ContractAddress,
    // spender requested amount
    pub requested_amount: u256,
}

/// @notice Used to reconstruct the signed permit message for multiple token transfers
/// @dev Do not need to pass in spender address as it is required that it is msg.sender
/// @dev Note that a user still signs over a spender address
#[derive(Drop, Serde)]
pub struct PermitBatchTransferFrom {
    // the tokens and corresponding amounts permitted for a transfer
    permitted: Span<TokenPermissions>,
    // a unique value for every token owner's signature to prevent signature replays
    nonce: u256,
    // deadline on the permit signature
    deadline: u256,
}

#[starknet::interface]
pub trait ISignatureTransfer<TState> {
    /// Reads ///
    /// @notice A map from token owner address and a caller specified word index to a bitmap. Used
    /// to set bits in the bitmap to prevent against signature replay protection @dev Uses unordered
    /// nonces so that permit messages do not need to be spent in a certain order @dev The mapping
    /// is indexed first by the token owner, then by an index specified in the nonce @dev It returns
    /// a uint256 bitmap @dev The index, or wordPosition is capped at type(uint248).max
    fn nonce_bitmap(self: @TState, owner: ContractAddress, index: u256) -> u256;


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
        signature: ByteArray,
    );

    /// @notice Transfers a token using a signed permit message
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include
    /// the TokenPermissions type definition @dev Reverts if the requested amount is greater than
    /// the permitted signed amount @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the
    /// typehash @param signature The signature to verify
    fn permit_witness_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
        owner: ContractAddress,
        witness: bytes31,
        witness_type_string: ByteArray,
        signature: ByteArray,
    );

    /// @notice Transfers multiple tokens using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param signature The signature to verify
    fn permit_transfer_from_batch(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        signature: ByteArray,
    );

    /// @notice Transfers multiple tokens using a signed permit message
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include
    /// the TokenPermissions type definition @notice Includes extra data provided by the caller to
    /// verify signature over @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the
    /// typehash @param signature The signature to verify
    fn permit_witness_transfer_from_batch(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        witness: bytes31,
        witness_type_string: ByteArray,
        signature: ByteArray,
    );

    /// @notice Invalidates the bits specified in mask for the bitmap at the word position
    /// @dev The wordPos is maxed at type(uint248).max
    /// @param wordPos A number to index the nonceBitmap at
    /// @param mask A bitmap masked against msg.sender's current bitmap at the word position
    fn invalidate_unordered_nonces(ref self: TState, word_pos: u256, mask: u256);
}
