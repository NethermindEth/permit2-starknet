use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12HashSpanImpl, StructHash};
use permit2::interfaces::allowance_transfer::{PermitBatch, PermitSingle};
use permit2::interfaces::permit2::{IPermit2Dispatcher, IPermit2DispatcherTrait};
use permit2::interfaces::signature_transfer::{PermitBatchTransferFrom, PermitTransferFrom};
use permit2::permit2::Permit2::SNIP12MetadataImpl;
use permit2::snip12_utils::permits::{
    PermitBatchStructHash, PermitBatchTransferFromOffChainMessageHashWitness,
    PermitBatchTransferFromStructHash, PermitBatchTransferFromStructHashWitness,
    PermitDetailsStructHash, PermitSingleStructHash, PermitTransferFromOffChainMessageHashWitness,
    PermitTransferFromStructHash, PermitTransferFromStructHashWitness, TokenPermissionsStructHash,
    U256StructHash, _PERMIT_BATCH_TRANSFER_FROM_TYPE_HASH, _PERMIT_BATCH_TYPE_HASH,
    _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH, _PERMIT_DETAILS_TYPE_HASH,
    _PERMIT_SINGLE_TYPE_HASH, _PERMIT_TRANSFER_FROM_TYPE_HASH,
    _PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH, _TOKEN_PERMISSIONS_TYPE_HASH, _U256_TYPE_HASH,
};
use snforge_std::{
    start_cheat_caller_address_global, start_cheat_chain_id_global,
    stop_cheat_caller_address_global, stop_cheat_chain_id_global,
};
use starknet::get_tx_info;
use crate::mocks::mock_witness::{BetaStructHash, MockWitnessStructHash, _WITNESS_TYPE_STRING_FULL};
use crate::setup::deploy_permit2;
use crate::utils::mock_structs::{
    make_permit_batch, make_permit_batch_transfer_from, make_permit_single,
    make_permit_transfer_from, make_witness, owner, spender,
};

const STARKNET_DOMAIN_TYPE_HASH: felt252 = selector!(
    "\"StarknetDomain\"(\"name\":\"shortstring\",\"version\":\"shortstring\",\"chainId\":\"shortstring\",\"revision\":\"shortstring\")",
);
const NAME: felt252 = 'Permit2';
const VERSION: felt252 = 'v1';
const REVISION: felt252 = 1;


#[test]
fn test_domain_separator() {
    let permit2_ = IPermit2Dispatcher { contract_address: deploy_permit2() };
    let expected = PoseidonTrait::new()
        .update_with(STARKNET_DOMAIN_TYPE_HASH)
        .update_with(NAME)
        .update_with(VERSION)
        .update_with(get_tx_info().unbox().chain_id)
        .update_with(REVISION)
        .finalize();

    assert_eq!(permit2_.DOMAIN_SEPARATOR(), expected);
}

#[test]
fn test_domain_separator_after_fork() {
    let permit2 = IPermit2Dispatcher { contract_address: deploy_permit2() };
    let beginning_separator = permit2.DOMAIN_SEPARATOR();
    let new_chain_id = get_tx_info().unbox().chain_id + 1;

    start_cheat_chain_id_global(new_chain_id);
    let expected = PoseidonTrait::new()
        .update_with(STARKNET_DOMAIN_TYPE_HASH)
        .update_with(NAME)
        .update_with(VERSION)
        .update_with(new_chain_id)
        .update_with(REVISION)
        .finalize();

    assert_ne!(beginning_separator, permit2.DOMAIN_SEPARATOR());
    assert_eq!(permit2.DOMAIN_SEPARATOR(), expected);

    stop_cheat_chain_id_global();
}

#[test]
fn test_type_hashes() {
    assert_eq!(_U256_TYPE_HASH, selector!("\"u256\"(\"low\":\"u128\",\"high\":\"u128\")"));
    assert_eq!(
        _PERMIT_SINGLE_TYPE_HASH,
        selector!(
            "\"Permit Single\"(\"Details\":\"Permit Details\",\"Spender\":\"ContractAddress\",\"Sig Deadline\":\"u256\")\"Permit Details\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\",\"Expiration\":\"timestamp\",\"Nonce\":\"timestamp\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")",
        ),
    );
    assert_eq!(
        _PERMIT_BATCH_TYPE_HASH,
        selector!(
            "\"Permit Batch\"(\"Details\":\"Permit Details*\",\"Spender\":\"ContractAddress\",\"Sig Deadline\":\"u256\")\"Permit Details\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\",\"Expiration\":\"timestamp\",\"Nonce\":\"timestamp\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")",
        ),
    );

    assert_eq!(
        _PERMIT_DETAILS_TYPE_HASH,
        selector!(
            "\"Permit Details\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\",\"Expiration\":\"timestamp\",\"Nonce\":\"timestamp\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")",
        ),
    );
    assert_eq!(
        _TOKEN_PERMISSIONS_TYPE_HASH,
        selector!(
            "\"Token Permissions\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")",
        ),
    );
    assert_eq!(
        _PERMIT_TRANSFER_FROM_TYPE_HASH,
        selector!(
            "\"Permit Transfer From\"(\"Permitted\":\"Token Permissions\",\"Spender\":\"ContractAddress\",\"Nonce\":\"felt\",\"Deadline\":\"u256\")\"Token Permissions\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")",
        ),
    );
    assert_eq!(
        _PERMIT_BATCH_TRANSFER_FROM_TYPE_HASH,
        selector!(
            "\"Permit Batch Transfer From\"(\"Permitted\":\"Token Permissions*\",\"Spender\":\"ContractAddress\",\"Nonce\":\"felt\",\"Deadline\":\"u256\")\"Token Permissions\"(\"Token\":\"ContractAddress\",\"Amount\":\"u256\")\"u256\"(\"low\":\"u128\",\"high\":\"u128\")",
        ),
    );

    assert_eq!(
        _PERMIT_WITNESS_TRANSFER_FROM_TYPE_HASH(_WITNESS_TYPE_STRING_FULL()),
        0xa41ec724bce4930ed80582ec1bd9b3d88e080632fcba86c8c93e96bfa3e297,
    );
    assert_eq!(
        _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPE_HASH(_WITNESS_TYPE_STRING_FULL()),
        0x326a8cfc454d9c4bf029694205291385b86581084e789ec7d991dcc4ee51aab,
    );
}

#[test]
fn test_permit_message_hash() {
    let permit_single: PermitSingle = make_permit_single();
    let permit_batch: PermitBatch = make_permit_batch();

    assert_eq!(
        permit_single.get_message_hash(owner()),
        0x794214c8a8edd8fef718f76d1685bb3a4c83415ce370d69258ae5844b45ed6e,
    );
    assert_eq!(
        permit_batch.get_message_hash(owner()),
        0x5d5dbaa6d5a4cf5410b16839b34ec489fc590f4471c3c88b68ddcccc9174f73,
    );
}

#[test]
fn test_permit_transfer_from_message_hash() {
    let permit_transfer_from: PermitTransferFrom = make_permit_transfer_from();
    let permit_batch_transfer_from: PermitBatchTransferFrom = make_permit_batch_transfer_from();

    // Caller is used as the spender field in these struct hashes
    start_cheat_caller_address_global(spender());
    assert_eq!(
        permit_transfer_from.get_message_hash(owner()),
        0x39ed11b65172537ff8cba38d301efa0a49f02eb392b238a8cde5e33684b0cae,
    );
    assert_eq!(
        permit_batch_transfer_from.get_message_hash(owner()),
        0x6df0ffdf8b15757b5c0899060a95375ae6f96da6d9b6e2d9d4a062d77134610,
    );
    stop_cheat_caller_address_global();
}

#[test]
fn test_permit_witness_transfer_from_message_hash() {
    start_cheat_caller_address_global(spender());
    let permit = make_permit_transfer_from();
    let witness = make_witness().hash_struct();
    assert_eq!(
        permit.get_message_hash_with_witness(owner(), witness, _WITNESS_TYPE_STRING_FULL()),
        0x527fab3a4f15f8580ca48249295da21df55baa9c9661ed1425aac50624daba1,
    );
    stop_cheat_caller_address_global();
}

#[test]
fn test_permit_witness_batch_transfer_from_message_hash() {
    start_cheat_caller_address_global(spender());
    let permit = make_permit_batch_transfer_from();
    let witness_data = make_witness();
    let witness = witness_data.hash_struct();

    assert_eq!(
        permit.get_message_hash_with_witness(owner(), witness, _WITNESS_TYPE_STRING_FULL()),
        0x2a85fe1f98bf044effb5171c76c10420be9a954d0d7df31349af0b9ca687564,
    );
    stop_cheat_caller_address_global();
}

