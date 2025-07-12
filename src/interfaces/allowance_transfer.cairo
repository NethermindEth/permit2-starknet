use starknet::ContractAddress;

#[starknet::interface]
pub trait IAllowanceTransfer<TState> {
    /// Reads ///

    /// Gets the allowance for a given owner, token, and spender.
    ///
    /// Parameters:
    ///
    /// - 'user': The owner of the tokens.
    /// - 'token': The token address to check the allowance for.
    /// - 'spender': The spender address to check the allowance for.
    ///
    /// Returns a tuple containing the allowed amount, expiration timestamp, and current nonce.
    fn allowance(
        self: @TState, user: ContractAddress, token: ContractAddress, spender: ContractAddress,
    ) -> (u256, u64, u64);


    /// Writes ///

    /// Approves the spender to use up to amount of the specified token up until the expiration.
    ///
    /// The nonce will stay unchanged in approve.
    ///
    /// Setting amount to type(uint256).max sets an unlimited approval.
    ///
    /// Parameters:
    ///
    /// - 'token': The token to approve.
    /// - 'spender': The spender address to approve.
    /// - 'amount': The approved amount of the token.
    /// - 'expiration': The timestamp at which the approval is no longer valid.
    fn approve(
        ref self: TState,
        token: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
    );

    /// Permit a spender to a given amount of the owner's token via the owner's snip-12 signature.
    ///
    /// May fail if the owner's nonce was invalidated in-flight by 'invalidate_nonce'.
    ///
    /// Parameters:
    ///
    /// - 'owner': The owner of the tokens being approved.
    /// - 'permit': Data signed over by the owner specifying the terms of approval.
    /// - 'signature': The owner's signature over the permit data.
    fn permit(
        ref self: TState, owner: ContractAddress, permit: PermitSingle, signature: Array<felt252>,
    );

    /// Permit a spender to the signed amounts of the owner's tokens via the owner's snip-12
    /// signature.
    ///
    /// May fail if the owner's nonce was invalidated in-flight by 'invalidate_nonce'.
    ///
    /// Parameters:
    ///
    /// - 'owner': The owner of the tokens being approved.
    /// - 'permit': Data signed over by the owner specifying the terms of approval.
    /// - 'signature': The owner's signature over the permit data.
    fn permit_batch(
        ref self: TState, owner: ContractAddress, permit: PermitBatch, signature: Array<felt252>,
    );

    /// Transfer approved tokens from one address to another.
    ///
    /// Requires the from address to have approved at least the desired amount of tokens to
    /// msg.sender.
    ///
    /// Parameters:
    ///
    /// - 'from': The address to transfer from.
    /// - 'to': The address of the recipient.
    /// - 'amount': The amount of the token to transfer.
    /// - 'token': The token address to transfer.
    fn transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    );

    /// Transfer approved tokens in a batch.
    ///
    /// Requires the from addresses to have approved at least the desired amount of tokens to
    /// msg.sender.
    ///
    /// Parameters:
    ///
    /// - 'transfer_details': Array of owners, recipients, amounts, and tokens for the transfers.
    fn batch_transfer_from(ref self: TState, transfer_details: Array<AllowanceTransferDetails>);

    /// Enables performing a "lockdown" of the sender's Permit2 identity by batch revoking
    /// approvals.
    ///
    /// Parameters:
    ///
    /// - 'approvals': Array of approvals to revoke.
    fn lockdown(ref self: TState, approvals: Array<TokenSpenderPair>);

    /// Invalidate nonces for a given (token, spender) pair.
    ///
    /// Parameters:
    ///
    /// - 'token': The token to invalidate nonces for.
    /// - 'spender': The spender to invalidate nonces for.
    /// - 'new_nonce': The new nonce to set. Invalidates all nonces less than it.
    ///
    /// Can't invalidate more than 2**16 nonces per transaction.
    fn invalidate_nonces(
        ref self: TState, token: ContractAddress, spender: ContractAddress, new_nonce: u64,
    );
}

/// The permit data for a token
/// @param token The ERC-20 token address
/// @param amount The maximum amount allowed to spend
/// @param expiration The timestamp at which a spender's token allowances become invalid
/// @param nonce An incrementing value indexed per owner, token, and spender for each signature
#[derive(Drop, Copy, Serde, Hash)]
pub struct PermitDetails {
    pub token: ContractAddress,
    pub amount: u256,
    pub expiration: u64,
    pub nonce: u64,
}

/// The permit message signed for a single token allowance
/// @param details The permit data for a single token allowance
/// @param spender The address permissioned on the allowed token
/// @param sig_deadline The deadline on the permit signature
#[derive(Drop, Copy, Serde, Hash)]
pub struct PermitSingle {
    pub details: PermitDetails,
    pub spender: ContractAddress,
    pub sig_deadline: u256,
}

/// The permit message signed for multiple token allowances
/// @param details The permit data for multiple token allowances
/// @param spender The address permissioned on the allowed tokens
/// @param sig_deadline The deadline on the permit signature
#[derive(Drop, Copy, Serde)]
pub struct PermitBatch {
    pub details: Span<PermitDetails>,
    pub spender: ContractAddress,
    pub sig_deadline: u256,
}

/// A token spender pair.
/// @param token The token address for which the spender is approved
/// @param spender The spender address that is approved to spend the token
#[derive(Copy, Drop, Serde)]
pub struct TokenSpenderPair {
    pub token: ContractAddress,
    pub spender: ContractAddress,
}

/// Details for a token transfer.
/// @param from The owner of the token being transferred
/// @param to The recipient of the token being transferred
/// @param amount The amount of the token being transferred
/// @param token The token address being transferred
#[derive(Copy, Drop, Serde)]
pub struct AllowanceTransferDetails {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub amount: u256,
    pub token: ContractAddress,
}

