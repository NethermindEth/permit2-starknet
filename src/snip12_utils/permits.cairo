use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::{
    SNIP12HashSpanImpl, SNIP12Metadata, StarknetDomain, StructHash,
};
use crate::interfaces::allowance_transfer::{PermitBatch, PermitDetails, PermitSingle};
use crate::interfaces::signature_transfer::{
    PermitBatchTransferFrom, PermitTransferFrom, TokenPermissions,
};
use crate::libraries::utils::selector;
use starknet::{ContractAddress, get_caller_address, get_tx_info};

/// TYPE HASHES (see tests/permit_hash_test.cairo)
pub const _U256_TYPE_HASH: felt252 =
    0x3b143be38b811560b45593fb2a071ec4ddd0a020e10782be62ffe6f39e0e82c;
pub const _PERMIT_DETAILS_TYPE_HASH: felt252 =
    0x39e80620ca03cbe1e7b789ce8f2316b9c8b6c51f3fd1f9fcfcf625e0f575e41;
pub const _PERMIT_SINGLE_TYPE_HASH: felt252 =
    0x3ba9155c2accbec95e96bd8b3a44001b999bcab5f60ac9190d52971e5e326d5;
pub const _PERMIT_BATCH_TYPE_HASH: felt252 =
    0x325274b0d8a3efb6f007445f02f582f1f1c1963a8f1ee25042907f932ff6dc6;
pub const _TOKEN_PERMISSIONS_TYPE_HASH: felt252 =
    0x361e49d30187edb379e9bf5a4352ec40a086ce44736d4f3827151e294f3636;
pub const _PERMIT_TRANSFER_FROM_TYPE_HASH: felt252 =
    0x91e237c508a467f4245435f0b4189c6ceea461866fc9f2d60e56044478423e;
pub const _PERMIT_BATCH_TRANSFER_FROM_TYPE_HASH: felt252 =
    0x4f4267c104a99f0b5310ca334394282d7676cf8b881c005b9ec165451d5fa0;

/// TYPE STRINGS
pub fn _PERMIT_WITNESS_TRANSFER_FROM_TYPE_STRING_STUB() -> ByteArray {
    "\"Permit Witness Transfer From\"(\"Permitted\":\"Token Permissions\",\"Spender\":\"ContractAddress\",\"Nonce\":\"felt\",\"Deadline\":\"u256\","
}

pub fn _PERMIT_WITNESS_BATCH_TRANSFER_FROM_TYPE_HASH_STUB() -> ByteArray {
    "\"Permit Witness Batch Transfer From\"(\"Permitted\":\"Token Permissions*\",\"Spender\":\"ContractAddress\",\"Nonce\":\"felt\",\"Deadline\":\"u256\","
}

pub fn _PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH(witness_type_string: ByteArray) -> felt252 {
    let stub = _PERMIT_WITNESS_TRANSFER_FROM_TYPE_STRING_STUB();
    selector(format!("{stub}{witness_type_string}"))
}

pub fn _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH(witness_type_string: ByteArray) -> felt252 {
    let stub = _PERMIT_WITNESS_BATCH_TRANSFER_FROM_TYPE_HASH_STUB();
    selector(format!("{stub}{witness_type_string}"))
}

/// HASHING STRUCTS
pub impl U256StructHash of StructHash<u256> {
    fn hash_struct(self: @u256) -> felt252 {
        PoseidonTrait::new().update_with(_U256_TYPE_HASH).update_with(*self).finalize()
    }
}

pub impl PermitSingleStructHash of StructHash<PermitSingle> {
    fn hash_struct(self: @PermitSingle) -> felt252 {
        PoseidonTrait::new()
            .update_with(_PERMIT_SINGLE_TYPE_HASH)
            .update_with(self.details.hash_struct())
            .update_with(*self.spender)
            .update_with(self.sig_deadline.hash_struct())
            .finalize()
    }
}

pub impl PermitBatchStructHash of StructHash<PermitBatch> {
    fn hash_struct(self: @PermitBatch) -> felt252 {
        let mut hashed_details = array![];
        for detail in *self.details {
            hashed_details.append(detail.hash_struct());
        };

        PoseidonTrait::new()
            .update_with(_PERMIT_BATCH_TYPE_HASH)
            .update_with(hashed_details.span())
            .update_with(*self.spender)
            .update_with(self.sig_deadline.hash_struct())
            .finalize()
    }
}

pub impl PermitTransferFromStructHash of StructHash<PermitTransferFrom> {
    fn hash_struct(self: @PermitTransferFrom) -> felt252 {
        PoseidonTrait::new()
            .update_with(_PERMIT_TRANSFER_FROM_TYPE_HASH)
            .update_with(self.permitted.hash_struct())
            .update_with(get_caller_address()) // Spender
            .update_with(*self.nonce)
            .update_with(self.deadline.hash_struct())
            .finalize()
    }
}

pub impl PermitBatchTransferFromStructHash of StructHash<PermitBatchTransferFrom> {
    fn hash_struct(self: @PermitBatchTransferFrom) -> felt252 {
        let mut hashed_permissions = array![];
        for permission in *self.permitted {
            hashed_permissions.append(permission.hash_struct());
        };

        PoseidonTrait::new()
            .update_with(_PERMIT_BATCH_TRANSFER_FROM_TYPE_HASH)
            .update_with(hashed_permissions.span())
            .update_with(get_caller_address())
            .update_with(*self.nonce)
            .update_with(self.deadline.hash_struct())
            .finalize()
    }
}

pub impl PermitDetailsStructHash of StructHash<PermitDetails> {
    fn hash_struct(self: @PermitDetails) -> felt252 {
        PoseidonTrait::new()
            .update_with(_PERMIT_DETAILS_TYPE_HASH)
            .update_with(*self.token)
            .update_with(self.amount.hash_struct())
            .update_with(*self.expiration)
            .update_with(*self.nonce)
            .finalize()
    }
}

pub impl TokenPermissionsStructHash of StructHash<TokenPermissions> {
    fn hash_struct(self: @TokenPermissions) -> felt252 {
        PoseidonTrait::new()
            .update_with(_TOKEN_PERMISSIONS_TYPE_HASH)
            .update_with(*self.token)
            .update_with(self.amount.hash_struct())
            .finalize()
    }
}

/// HASHING STRUCTS WITH WITNESS

pub trait StructHashWitnessTrait<T> {
    fn hash_with_witness(self: @T, witness: felt252, witness_type_string: ByteArray) -> felt252;
}

pub impl PermitTransferFromStructHashWitness of StructHashWitnessTrait<PermitTransferFrom> {
    fn hash_with_witness(
        self: @PermitTransferFrom, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252 {
        PoseidonTrait::new()
            .update_with(_PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH(witness_type_string))
            .update_with(self.permitted.hash_struct())
            .update_with(get_caller_address())
            .update_with(*self.nonce)
            .update_with(self.deadline.hash_struct())
            .update_with(witness)
            .finalize()
    }
}

pub impl PermitBatchTransferFromStructHashWitness of StructHashWitnessTrait<
    PermitBatchTransferFrom,
> {
    fn hash_with_witness(
        self: @PermitBatchTransferFrom, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252 {
        let mut hashed_permissions = array![];
        for permission in *self.permitted {
            hashed_permissions.append(permission.hash_struct());
        };

        PoseidonTrait::new()
            .update_with(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH(witness_type_string))
            .update_with(hashed_permissions.span())
            .update_with(get_caller_address())
            .update_with(*self.nonce)
            .update_with(self.deadline.hash_struct())
            .update_with(witness)
            .finalize()
    }
}

/// OFFCHAIN MESSAGE HASHING WITH WITNESS ///
pub trait OffchainMessageHashWitnessTrait<T> {
    fn get_message_hash_with_witness(
        self: @T, signer: ContractAddress, witness: felt252, witness_type_string: ByteArray,
    ) -> felt252;
}

pub impl PermitTransferFromOffChainMessageHashWitness<
    impl metadata: SNIP12Metadata,
> of OffchainMessageHashWitnessTrait<PermitTransferFrom> {
    fn get_message_hash_with_witness(
        self: @PermitTransferFrom,
        signer: ContractAddress,
        witness: felt252,
        witness_type_string: ByteArray,
    ) -> felt252 {
        let domain = StarknetDomain {
            name: metadata::name(),
            version: metadata::version(),
            chain_id: get_tx_info().unbox().chain_id,
            revision: 1,
        };

        let hashed_permit = PoseidonTrait::new()
            .update_with(_PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH(witness_type_string))
            .update_with((*self.permitted).hash_struct())
            .update_with(get_caller_address())
            .update_with(*self.nonce)
            .update_with(self.deadline.hash_struct())
            .update_with(witness)
            .finalize();

        PoseidonTrait::new()
            // Domain
            .update_with('StarkNet Message')
            .update_with(domain.hash_struct())
            // Account
            .update_with(signer)
            // Message
            .update_with(hashed_permit)
            .finalize()
    }
}

pub impl PermitBatchTransferFromOffChainMessageHashWitness<
    impl metadata: SNIP12Metadata,
> of OffchainMessageHashWitnessTrait<PermitBatchTransferFrom> {
    fn get_message_hash_with_witness(
        self: @PermitBatchTransferFrom,
        signer: ContractAddress,
        witness: felt252,
        witness_type_string: ByteArray,
    ) -> felt252 {
        let domain = StarknetDomain {
            name: metadata::name(),
            version: metadata::version(),
            chain_id: get_tx_info().unbox().chain_id,
            revision: 1,
        };
        let mut hashed_permissions = array![];
        for permission in *self.permitted {
            hashed_permissions.append(permission.hash_struct());
        };

        let hashed_permit = PoseidonTrait::new()
            .update_with(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH(witness_type_string))
            .update_with(hashed_permissions.span())
            .update_with(get_caller_address())
            .update_with(*self.nonce)
            .update_with(self.deadline.hash_struct())
            .update_with(witness)
            .finalize();

        PoseidonTrait::new()
            // Domain
            .update_with('StarkNet Message')
            .update_with(domain.hash_struct())
            // Account
            .update_with(signer)
            // Message
            .update_with(hashed_permit)
            .finalize()
    }
}
