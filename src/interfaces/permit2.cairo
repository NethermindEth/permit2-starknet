use starknet::ContractAddress;
use crate::interfaces::allowance_transfer::{
    PermitSingle, PermitBatch, AllowanceTransferDetails, TokenSpenderPair,
};
use crate::interfaces::signature_transfer::{
    PermitTransferFrom, PermitBatchTransferFrom, SignatureTransferDetails,
};


#[starknet::interface]
pub trait IDomainSeparator<TState> {
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
}

#[starknet::interface]
pub trait IPermit2ABI<TState> {
    /// IDomainSeparator ///
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
    /// IAllowanceTransfer ///
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
        ref self: TState, owner: ContractAddress, permit: PermitSingle, signature: Array<felt252>,
    );
    fn permit_batch(
        ref self: TState, owner: ContractAddress, permit: PermitBatch, signature: Array<felt252>,
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
    /// ISignatrueTransfer ///
    fn permit_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
        owner: ContractAddress,
        signature: Array<felt252>,
    );
    fn permit_batch_transfer_from(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        signature: Array<felt252>,
    );
    fn permit_witness_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
        owner: ContractAddress,
        witness: felt252,
        witness_type_string: ByteArray,
        signature: Array<felt252>,
    );
    fn permit_witness_batch_transfer_from(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
        witness: felt252,
        witness_type_string: ByteArray,
        signature: Array<felt252>,
    );
    /// IUnorderedNonces ///
    fn nonce_bitmap(self: @TState, owner: ContractAddress, nonce_space: felt252) -> felt252;
    fn is_nonce_usable(self: @TState, owner: ContractAddress, nonce: felt252) -> bool;
    fn invalidate_unordered_nonces(ref self: TState, nonce_space: felt252, mask: felt252);
}

