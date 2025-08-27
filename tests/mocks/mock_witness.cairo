use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::{SNIP12HashSpanImpl, StructHash};
//use permit2::permit2::signature_transfer::interface::TokenPermissions;
//use starknet::get_caller_address;
use permit2::libraries::utils::selector;
use permit2::snip12_utils::permits::{
    TokenPermissionsStructHash,
    U256StructHash // _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH, _PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH,
};

/// Example witness

#[derive(Drop, Copy, Serde, Debug)]
pub struct MockWitness {
    pub a: u128,
    pub b: Beta,
    pub z: Zeta,
}
pub fn _MOCK_WITNESS_TYPE_STRING_PARTIAL() -> ByteArray {
    "\"Mock Witness\"(\"A\":\"u128\",\"B\":\"Beta\",\"Z\":\"Zeta\")"
}

#[derive(Drop, Copy, Serde, Debug)]
pub struct Beta {
    pub b1: u128,
    pub b2: Span<felt252>,
}
pub fn _BETA_TYPE_STRING() -> ByteArray {
    "\"Beta\"(\"B 1\":\"u128\",\"B 2\":\"felt*\")"
}

#[derive(Drop, Copy, Serde, Debug)]
pub struct Zeta {
    pub z1: felt252,
    pub z2: Span<felt252>,
}
pub fn _ZETA_TYPE_STRING() -> ByteArray {
    "\"Zeta\"(\"Z 1\":\"felt\",\"Z 2\":\"felt*\")"
}

// Other type strings needed to create the witness type string (u256, TokenPermissions)
pub fn _U256_TYPE_STRING() -> ByteArray {
    "\"u256\"(\"low\":\"u128\",\"high\":\"u128\")"
}
pub fn _TOKEN_PERMISSIONS_TYPE_STRING() -> ByteArray {
    "\"Token Permissions\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\")"
}


/// Creating the witness type string

// The outcome of this function is the full witness type string for the `MockWitness` struct
// NOTE:
// - The witness type string must include the TokenPermissions & u256 type strings after the witness
// type definition
// - If the witness type includes any reference types, they must be sorted
// alphabetically with TokenPermissions & u256
pub fn _WITNESS_TYPE_STRING_FULL() -> ByteArray {
    format!(
        "\"Witness\":\"Mock Witness\"){}{}{}{}{}",
        _BETA_TYPE_STRING(),
        _MOCK_WITNESS_TYPE_STRING_PARTIAL(),
        _TOKEN_PERMISSIONS_TYPE_STRING(),
        _ZETA_TYPE_STRING(),
        _U256_TYPE_STRING(),
    )
}

pub fn _MOCK_WITNESS_TYPE_STRING() -> ByteArray {
    format!("{}{}{}", _MOCK_WITNESS_TYPE_STRING_PARTIAL(), _BETA_TYPE_STRING(), _ZETA_TYPE_STRING())
}

//pub fn _MOCK_WITNESS_TYPE_STRING() -> ByteArray {
//    format!(
//        "{}{}{}{}{}",
//        _MOCK_WITNESS_TYPE_STRING_PARTIAL(),
//        _BETA_TYPE_STRING(),
//        _TOKEN_PERMISSIONS_TYPE_STRING(),
//        _U256_TYPE_STRING(),
//        _ZETA_TYPE_STRING(),
//    )
//}

/// NOTE: MIGHT NOT BE NECESSARY

// Get struct hash for Span<felt252>
pub impl StructHashSpanFelt252 of StructHash<Span<felt252>> {
    fn hash_struct(self: @Span<felt252>) -> felt252 {
        let mut state = PoseidonTrait::new();
        for el in (*self) {
            state = state.update_with(*el);
        };
        state.finalize()
    }
}
// Get struct hash for Span<u128>
pub impl StructHashSpanU128 of StructHash<Span<u128>> {
    fn hash_struct(self: @Span<u128>) -> felt252 {
        let mut state = PoseidonTrait::new();
        for el in (*self) {
            state = state.update_with(*el);
        };
        state.finalize()
    }
}

// Get struct hash for Beta
pub impl BetaStructHash of StructHash<Beta> {
    fn hash_struct(self: @Beta) -> felt252 {
        PoseidonTrait::new()
            .update_with(selector(_BETA_TYPE_STRING()))
            .update_with(*self.b1)
            .update_with(self.b2.hash_struct())
            .finalize()
    }
}
// Get struct hash for Zeta
pub impl ZetaStructHash of StructHash<Zeta> {
    fn hash_struct(self: @Zeta) -> felt252 {
        PoseidonTrait::new()
            .update_with(selector(_ZETA_TYPE_STRING()))
            .update_with(*self.z1)
            .update_with(self.z2.hash_struct())
            .finalize()
    }
}

// Get struct hash for MockWitness
pub impl MockWitnessStructHash of StructHash<MockWitness> {
    fn hash_struct(self: @MockWitness) -> felt252 {
        PoseidonTrait::new()
            .update_with(selector(_MOCK_WITNESS_TYPE_STRING()))
            .update_with(*self.a)
            .update_with(self.b.hash_struct())
            .update_with(self.z.hash_struct())
            .finalize()
    }
}
// #[derive(Drop, Copy, Serde, Debug)]
// pub struct PermitWitnessTransferFrom {
//     pub permitted: TokenPermissions,
//     pub nonce: felt252,
//     pub deadline: u256,
//     pub witness: MockWitness,
// }
//
// #[derive(Drop, Copy, Serde, Debug)]
// pub struct PermitWitnessBatchTransferFrom {
//     pub permitted: Span<TokenPermissions>,
//     pub nonce: felt252,
//     pub deadline: u256,
//     pub witness: MockWitness,
// }
//
// pub impl PermitWitnessTransferFromStructHash of StructHash<PermitWitnessTransferFrom> {
//     fn hash_struct(self: @PermitWitnessTransferFrom) -> felt252 {
//         PoseidonTrait::new()
//             .update_with(_PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH(_WITNESS_TYPE_STRING_FULL()))
//             .update_with(self.permitted.hash_struct())
//             .update_with(get_caller_address())
//             .update_with(*self.nonce)
//             .update_with(self.deadline.hash_struct())
//             .update_with(self.witness.hash_struct())
//             .finalize()
//     }
// }
//
// pub impl PermitWitnessBatchTransferFromStructHash of StructHash<PermitWitnessBatchTransferFrom> {
//     fn hash_struct(self: @PermitWitnessBatchTransferFrom) -> felt252 {
//         let hashed_permissions = self
//             .permitted
//             .into_iter()
//             .map(|permission| permission.hash_struct())
//             .collect::<Array<felt252>>()
//             .span();
//         println!(
//             "INNER:\n{}", _PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH(_WITNESS_TYPE_STRING_FULL()),
//         );
//
//         PoseidonTrait::new()
//             .update_with(_PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH(_WITNESS_TYPE_STRING_FULL()))
//             .update_with(hashed_permissions)
//             .update_with(get_caller_address())
//             .update_with(*self.nonce)
//             .update_with(self.deadline.hash_struct())
//             .update_with(self.witness.hash_struct())
//             .finalize()
//     }
// }


