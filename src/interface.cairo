use permit2::interfaces::allowance_transfer::{
    AllowanceTransferDetails, PermitBatch, PermitSingle, TokenSpenderPair,
};
use permit2::interfaces::signature_transfer::{
    PermitBatchTransferFrom, PermitTransferFrom, SignatureTransferDetails,
};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IPermit2<TState> {
    /// Reads ///

    /// AllowanceTransfer

    fn allowance(
        self: @TState, user: ContractAddress, token: ContractAddress, spender: ContractAddress,
    ) -> (u256, u64, u64);

    /// UnorderedNonces

    fn nonce_bitmap(self: @TState, owner: ContractAddress, nonce_space: felt252) -> felt252;

    fn is_nonce_usable(self: @TState, owner: ContractAddress, nonce: felt252) -> bool;


    /// Writes ///

    /// AllowanceTransfer

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

    /// SignatureTransfer

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

    /// UnorderedNonces

    fn invalidate_unordered_nonces(ref self: TState, nonce_space: felt252, mask: felt252);
}
