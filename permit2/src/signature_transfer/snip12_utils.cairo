use core::hash::{HashStateExTrait, HashStateTrait};
use core::keccak::compute_keccak_byte_array;
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::{SNIP12HashSpanImpl, StructHash};
use starknet::ContractAddress;
use crate::signature_transfer::interface::{
    PermitBatchTransferFrom, PermitTransferFrom, TokenPermissions,
};

/// SNIP-12 TYPE_HASHES ///
/// structs:
/// - TokenPermissions
/// - PermitTransferFrom
/// - PermitBatchTransferFrom
/// - PermitWitnessTransferFrom
/// - PermitWitnessBatchTransferFrom


pub const TOKEN_PERMISSIONS_TYPEHASH: felt252 = selector!(
    "\"TokenPermissions\"(
        \"token\":\"ContractAddress\",
        \"amount\":\"u256\",
    )\"u256\"(
        \"low\":\"u128\",
        \"high\":\"u128\"
    )",
);

pub const PERMIT_TRANSFER_FROM_TYPEHASH: felt252 = selector!(
    "\"PermitTransferFrom\"(
        \"permitted\":\"TokenPermissions\",
        \"spender\":\"ContractAddress\",
        \"nonce\":\"felt\",
        \"deadline\":\"u256\",
    )\"TokenPermissions\"(
        \"token\":\"ContractAddress\",
        \"amount\":\"u256\",
    )\"u256\"(
        \"low\":\"u128\",
        \"high\":\"u128\"
    )",
);

pub const PERMIT_BATCH_TRANSFER_FROM_TYPEHASH: felt252 = selector!(
    "\"PermitBatchTransferFrom\"(
        \"permitted\":\"TokenPermissions*\",
        \"spender\":\"ContractAddress\",
        \"nonce\":\"felt\",
        \"deadline\":\"u256\",
    )\"TokenPermissions\"(
        \"token\":\"ContractAddress\",
        \"amount\":\"u256\",
    )\"u256\"(
        \"low\":\"u128\",
        \"high\":\"u128\"
    )",
);


/// @dev Witness injection

pub fn PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH(witness_type_string: ByteArray) -> felt252 {
    /// TODO: ensure output matches with `selector!()`
    compute_keccak_byte_array(
        @format!(
            "\"PermitWitnessTransferFrom\"(
                \"permitted\":\"TokenPermissions\",
                \"spender\":\"ContractAddress\",
                \"nonce\":\"felt\",
                \"deadline\":\"u256\",
                {witness_type_string},
            )\"TokenPermissions\"(
                \"token\":\"ContractAddress\",
                \"amount\":\"u256\",
            )\"u256\"(
                \"low\":\"u128\",
                \"high\":\"u128\"
            )",
        ),
    );
    0
}

pub fn PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB(witness_type_string: ByteArray) -> felt252 {
    /// TODO: ensure output matches with `selector!()`
    compute_keccak_byte_array(
        @format!(
            "\"PermitBatchWitnessTransferFrom\"(
                \"permitted\":\"TokenPermissions*\",
                \"spender\":\"ContractAddress\",
                \"nonce\":\"felt\",
                \"deadline\":\"u256\",
                {witness_type_string},
            )\"TokenPermissions\"(
                \"token\":\"ContractAddress\",
                \"amount\":\"u256\",
            )\"u256\"(
                \"low\":\"u128\",
                \"high\":\"u128\"
            )",
        ),
    );
    0
}

/// HASHING STRUCTS ///
/// structs:
/// - TokenPermissions
/// - PermitTransferFrom
/// - PermitBatchTransferFrom


pub impl TokenPermissionsStructHash of StructHash<TokenPermissions> {
    fn hash_struct(self: @TokenPermissions) -> felt252 {
        PoseidonTrait::new().update_with(TOKEN_PERMISSIONS_TYPEHASH).update_with(*self).finalize()
    }
}

pub impl StructHashPermitTransferFrom of StructHash<PermitTransferFrom> {
    fn hash_struct(self: @PermitTransferFrom) -> felt252 {
        PoseidonTrait::new()
            .update_with(TOKEN_PERMISSIONS_TYPEHASH)
            .update_with(self.permitted.hash_struct())
            .update_with(starknet::get_caller_address())
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .finalize()
    }

}

pub impl StructHashPermitBatchTransferFrom of StructHash<PermitBatchTransferFrom> {
    fn hash_struct(self: @PermitBatchTransferFrom) -> felt252 {
        let hashed_permissions = self
            .permitted
            .into_iter()
            .map(|permission| permission.hash_struct())
            .collect::<Array<felt252>>()
            .span();

        PoseidonTrait::new()
            .update_with(PERMIT_BATCH_TRANSFER_FROM_TYPEHASH)
            .update_with(hashed_permissions)
            .update_with(starknet::get_caller_address())
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .finalize()
    }
}

/// OFFCHAIN MESSAGES ///

/// off-chain messages:
/// - PermitTransferFrom
/// - PermitBatchTransferFrom

#[derive(Drop, Copy)]
pub struct PermitTransferFromMessage {
    pub permitted: TokenPermissions,
    pub spender: ContractAddress,
    pub nonce: felt252,
    pub deadline: u256,
}

#[derive(Drop, Copy)]
pub struct PermitBatchTransferFromMessage {
    pub permitted: Span<TokenPermissions>,
    pub spender: ContractAddress,
    pub nonce: felt252,
    pub deadline: u256,
}

/// HASHING OFFCHAIN MESSAGES ///

/// off-chain messages:
/// - PermitTransferFrom
/// - PermitBatchTransferFrom

// @dev unused ?
pub impl OffChainMessageHashPermitTransferFrom of StructHash<PermitTransferFromMessage> {
    fn hash_struct(self: @PermitTransferFromMessage) -> felt252 {
        PoseidonTrait::new()
            .update_with(TOKEN_PERMISSIONS_TYPEHASH)
            .update_with(self.permitted.hash_struct())
            .update_with(*self.spender)
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .finalize()
    }
}

pub impl OffChainMessageHashPermitBatchTransferFrom of StructHash<PermitBatchTransferFromMessage> {
    fn hash_struct(self: @PermitBatchTransferFromMessage) -> felt252 {
        let hashed_permissions = self
            .permitted
            .into_iter()
            .map(|permission| permission.hash_struct())
            .collect::<Array<felt252>>()
            .span();

        PoseidonTrait::new()
            .update_with(PERMIT_BATCH_TRANSFER_FROM_TYPEHASH)
            .update_with(hashed_permissions)
            .update_with(*self.spender)
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .finalize()
    }
}


/// HASHING STRUCTS WITH WITNESS ///
/// structs:
/// - PermitTransferFrom
/// - PermitBatchTransferFrom

pub trait StructHashWitnessTrait<T> {
    fn hash_with_witness(self: @T, witness: felt252, witness_type_string: ByteArray) -> felt252;
}

impl StructHashWitnessPermitTransferFrom of StructHashWitnessTrait<PermitTransferFrom> {
    fn hash_with_witness(
        self: @PermitTransferFrom, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252 {
        PoseidonTrait::new()
            .update_with(PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH(witness_type_string))
            .update_with(self.permitted.hash_struct())
            .update_with(starknet::get_caller_address())
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .update_with(witness)
            .finalize()
    }
}

impl StructHashWitnessPermitBatchTransferFrom of StructHashWitnessTrait<PermitBatchTransferFrom> {
    fn hash_with_witness(
        self: @PermitBatchTransferFrom, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252 {
        let hashed_permissions = self
            .permitted
            .into_iter()
            .map(|permission| permission.hash_struct())
            .collect::<Array<felt252>>()
            .span();

        PoseidonTrait::new()
            .update_with(PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB(witness_type_string))
            .update_with(hashed_permissions)
            .update_with(starknet::get_caller_address())
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .update_with(witness)
            .finalize()
    }
}

/// HASHING OFFCHAIN MESSAGES WITH WITNESS ///
/// structs:
/// - PermitTransferFrom
/// - PermitBatchTransferFrom

impl OffChainMessageHashWitnessPermitTransferFrom of StructHashWitnessTrait<
    PermitTransferFromMessage,
> {
    fn hash_with_witness(
        self: @PermitTransferFromMessage, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252 {
        PoseidonTrait::new()
            .update_with(PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH(witness_type_string))
            .update_with(self.permitted.hash_struct())
            .update_with(*self.spender)
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .update_with(witness)
            .finalize()
    }
}

impl OffChainMessageHashWitnessPermitBatchTransferFrom of StructHashWitnessTrait<
    PermitBatchTransferFromMessage,
> {
    fn hash_with_witness(
        self: @PermitBatchTransferFromMessage, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252 {
        let hashed_permissions = self
            .permitted
            .into_iter()
            .map(|permission| permission.hash_struct())
            .collect::<Array<felt252>>()
            .span();

        PoseidonTrait::new()
            .update_with(PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB(witness_type_string))
            .update_with(hashed_permissions)
            .update_with(*self.spender)
            .update_with(*self.nonce)
            .update_with(*self.deadline)
            .update_with(witness)
            .finalize()
    }
}
