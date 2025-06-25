// IAllowanceTransfer.cairo
use starknet::ContractAddress;

/// @notice The permit data for a token
#[derive(Drop, Serde)]
pub struct PermitDetails {
    // ERC20 token address
    token: ContractAddress,
    // the maximum amount allowed to spend
    amount: u256,
    // timestamp at which a spender's token allowances become invalid
    expiration: u64,
    // an incrementing value indexed per owner,token,and spender for each signature
    nonce: u64,
}

/// @notice The permit message signed for a single token allowance
#[derive(Drop, Serde)]
pub struct PermitSingle {
    // the permit data for a single token allowance
    details: PermitDetails,
    // address permissioned on the allowed tokens
    spender: ContractAddress,
    // deadline on the permit signature
    sigDeadline: u256,
}

/// @notice The permit message signed for multiple token allowances
#[derive(Drop, Serde)]
pub struct PermitBatch {
    // the permit data for multiple token allowances
    details: Span<PermitDetails>,
    // address permissioned on the allowed tokens
    spender: ContractAddress,
    // deadline on the permit signature
    sigDeadline: u256,
}

/// @notice The saved permissions
/// @dev This info is saved per owner, per token, per spender and all signed over in the permit
/// message @dev Setting amount to type(uint160).max sets an unlimited approval
pub struct PackedAllowance {
    // amount allowed
    amount: u256,
    // permission expiry
    expiration: u64,
    // an incrementing value indexed per owner,token,and spender for each signature
    nonce: u64,
}

/// @notice A token spender pair.

#[derive(Drop, Serde)]
pub struct TokenSpenderPair {
    // the token the spender is approved
    token: ContractAddress,
    // the spender address
    spender: ContractAddress,
}

/// @notice Details for a token transfer.
#[derive(Drop, Serde)]
pub struct AllowanceTransferDetails {
    // the owner of the token
    from: ContractAddress,
    // the recipient of the token
    to: ContractAddress,
    // the amount of the token
    amount: u256,
    // the token to be transferred
    token: ContractAddress,
}

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
        ref self: TState, owner: ContractAddress, permitSingle: PermitSingle, signature: ByteArray,
    );

    /// @notice Permit a spender to the signed amounts of the owners tokens via the owner's EIP-712
    /// signature @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitBatch Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data

    fn permit_batch(
        ref self: TState, owner: ContractAddress, permitSingle: PermitBatch, signature: ByteArray,
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
    fn transfer_from_batch(ref self: TState, transferDetails: Span<AllowanceTransferDetails>);

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals
    /// @param approvals Array of approvals to revoke.
    fn lockdown(ref self: TState, approvals: Span<TokenSpenderPair>);

    /// @notice Invalidate nonces for a given (token, spender) pair
    /// @param token The token to invalidate nonces for
    /// @param spender The spender to invalidate nonces for
    /// @param newNonce The new nonce to set. Invalidates all nonces less than it.
    /// @dev Can't invalidate more than 2**16 nonces per transaction.
    fn invalidate_nonces(
        ref self: TState, token: ContractAddress, spender: ContractAddress, new_nonce: u64,
    );
}
