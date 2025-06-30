use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::{SNIP12HashSpanImpl, StructHash};
use crate::allowance_transfer::interface::{PermitBatch, PermitDetails, PermitSingle};

/// SNIP12 TYPE_HASH of PermitDetails struct.
/// There's no u8 in SNIP-12, we use u128
pub const PERMIT_DETAILS_TYPEHASH: felt252 = selector!(
    "\"PermitDetails\"(
        \"token\":\"ContractAddress\",
        \"amount\":\"u256\",
        \"expiration\":\"u128\",
        \"nonce\":\"u128\",
    )\"u256\"(
        \"low\":\"u128\",
        \"high\":\"u128\"
    )",
);

pub impl PermitDetailsStructHash of StructHash<PermitDetails> {
    fn hash_struct(self: @PermitDetails) -> felt252 {
        PoseidonTrait::new().update_with(PERMIT_DETAILS_TYPEHASH).update_with(*self).finalize()
    }
}
/// SNIP12 TYPE_HASH of PermitSingle struct.
pub const PERMIT_SINGLE_TYPEHASH: felt252 = selector!(
    "\"PermitSingle\"(
        \"details\":\"PermitDetails\",
        \"spender\":\"ContractAddress\",
        \"sig_deadline\":\"u256\",
    )\"PermitDetails\"(
        \"token\":\"ContractAddress\",
        \"amount\":\"u256\",
        \"expiration\":\"u128\",
        \"nonce\":\"u128\",
    )\"u256\"(
        \"low\":\"u128\",
        \"high\":\"u128\"
    )",
);

pub impl PermitSingleStructHash of StructHash<PermitSingle> {
    fn hash_struct(self: @PermitSingle) -> felt252 {
        PoseidonTrait::new()
            .update_with(PERMIT_SINGLE_TYPEHASH)
            .update_with(self.details.hash_struct())
            .update_with(*self.spender)
            .update_with(*self.sig_deadline)
            .finalize()
    }
}

/// SNIP12 TYPE_HASH of PermitBatch struct.
pub const PERMIT_BATCH_TYPEHASH: felt252 = selector!(
    "\"PermitBatch\"(
        \"details\":\"PermitDetails*\",
        \"spender\":\"ContractAddress\",
        \"sig_deadline\":\"u256\",
    )\"PermitDetails\"(
        \"token\":\"ContractAddress\",
        \"amount\":\"u256\",
        \"expiration\":\"u128\",
        \"nonce\":\"u128\",
    )\"u256\"(
        \"low\":\"u128\",
        \"high\":\"u128\"
    )",
);

pub impl PermitBatchStructHash of StructHash<PermitBatch> {
    fn hash_struct(self: @PermitBatch) -> felt252 {
        let hashed_details = self
            .details
            .into_iter()
            .map(|detail| detail.hash_struct())
            .collect::<Array<felt252>>()
            .span();

        PoseidonTrait::new()
            .update_with(PERMIT_BATCH_TYPEHASH)
            .update_with(hashed_details)
            .update_with(*self.spender)
            .update_with(*self.sig_deadline)
            .finalize()
    }
}
