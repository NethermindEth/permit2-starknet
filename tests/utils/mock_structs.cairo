use permit2::interfaces::allowance_transfer::{PermitBatch, PermitDetails, PermitSingle};
use permit2::interfaces::signature_transfer::{
    PermitBatchTransferFrom, PermitTransferFrom, TokenPermissions,
};
use permit2::mocks::mock_witness::{Beta, MockWitness, MockWitnessStructHash, Zeta};
use permit2::permit2::Permit2::SNIP12MetadataImpl;
use permit2::snip12_utils::permits::{
    PermitBatchStructHash, PermitBatchTransferFromStructHash,
    PermitBatchTransferFromStructHashWitness, PermitDetailsStructHash, PermitSingleStructHash,
    PermitTransferFromStructHash, PermitTransferFromStructHashWitness, TokenPermissionsStructHash,
    U256StructHash,
};
use starknet::ContractAddress;


pub const spender: ContractAddress = 0x5678.try_into().unwrap();
pub const owner: ContractAddress = 0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec
    .try_into()
    .unwrap();


pub fn make_permit_single() -> PermitSingle {
    let token: ContractAddress = 0x1234.try_into().unwrap();
    let amount = 0x1;
    let expiration = 12345;
    let nonce = 1;
    let sig_deadline = 0x1234567890;

    PermitSingle {
        details: PermitDetails { token, amount, expiration, nonce }, spender: spender, sig_deadline,
    }
}

pub fn make_permit_batch() -> PermitBatch {
    let token: ContractAddress = 0x1234.try_into().unwrap();
    let amount = 0x1;
    let expiration = 12345;
    let nonce = 1;
    let spender = 0x5678.try_into().unwrap();
    let sig_deadline = 0x1234567890;
    let details = PermitDetails { token, amount, expiration, nonce };

    PermitBatch { details: array![details, details].span(), spender, sig_deadline }
}

pub fn make_permit_transfer_from() -> PermitTransferFrom {
    let token: ContractAddress = 0x1234.try_into().unwrap();
    let amount = 0x1;
    let nonce = 1;
    let deadline = 0x1234567890;

    PermitTransferFrom { permitted: TokenPermissions { token, amount }, nonce, deadline }
}

pub fn make_permit_batch_transfer_from() -> PermitBatchTransferFrom {
    let token: ContractAddress = 0x1234.try_into().unwrap();
    let amount = 0x1;
    let nonce = 1;
    let deadline = 0x1234567890;
    let permitted = TokenPermissions { token, amount };

    PermitBatchTransferFrom { permitted: array![permitted, permitted].span(), nonce, deadline }
}

pub fn make_witness() -> MockWitness {
    let b2: Span<felt252> = array![3, 4].span();
    let z2: Span<felt252> = array![6, 7].span();

    MockWitness { a: 1, b: Beta { b1: 2, b2 }, z: Zeta { z1: 5, z2 } }
}

