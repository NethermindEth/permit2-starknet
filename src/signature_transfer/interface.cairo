use starknet::ContractAddress;

#[derive(Drop, Copy, Hash, Serde)]
pub struct TokenPermissions {
    pub token: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, Copy, Hash, Serde)]
pub struct PermitTransferFrom {
    pub permitted: TokenPermissions,
    pub nonce: felt252,
    pub deadline: u256,
}

#[derive(Drop, Copy, Hash, Serde)]
pub struct SignatureTransferDetails {
    pub to: ContractAddress,
    pub requested_amount: u256,
}

#[derive(Drop, Copy, Serde)]
pub struct PermitBatchTransferFrom {
    pub permitted: Span<TokenPermissions>,
    pub nonce: felt252,
    pub deadline: u256,
}

#[starknet::interface]
pub trait ISignatureTransfer<TState> {
    fn permit_transfer_from(
        ref self: TState,
        permit: PermitTransferFrom,
        transfer_details: SignatureTransferDetails,
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
    fn permit_batch_transfer_from(
        ref self: TState,
        permit: PermitBatchTransferFrom,
        transfer_details: Span<SignatureTransferDetails>,
        owner: ContractAddress,
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
}
