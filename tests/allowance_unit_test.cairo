use core::num::traits::Bounded;
use permit2::libraries::allowance::{Allowance, AllowanceTrait};
use starknet::ContractAddress;
use starknet::storage::{
    Mutable, StoragePath, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
};

fn FROM() -> ContractAddress {
    'FROM'.try_into().unwrap()
}
fn SPENDER() -> ContractAddress {
    'SPENDER'.try_into().unwrap()
}
fn TOKEN() -> ContractAddress {
    'TOKEN'.try_into().unwrap()
}

fn setup() -> StoragePath<Mutable<Allowance>> {
    let mut allowance_contract_state = contract_with_allowance::contract_state_for_testing();
    let mut allowance_storage = allowance_contract_state
        .allowance
        .entry((FROM(), TOKEN(), SPENDER()));

    return allowance_storage;
}

#[starknet::contract]
mod contract_with_allowance {
    use permit2::libraries::allowance::Allowance;
    use starknet::ContractAddress;
    use starknet::storage::Map;

    #[storage]
    pub struct Storage {
        pub allowance: Map<(ContractAddress, ContractAddress, ContractAddress), Allowance>,
    }
}


#[test]
#[fuzzer]
fn test_should_update_amount_and_expiration_randomly(amount: u256, expiration: u64) {
    let mut allowance_storage = setup();
    let nonce_before = allowance_storage.read().nonce;

    allowance_storage.update_amount_and_expiration(amount, expiration);

    let timestamp_after_upgrade = if expiration == 0 {
        starknet::get_block_timestamp()
    } else {
        expiration
    };
    let allowance_after = allowance_storage.read();

    assert_eq!(allowance_after.amount, amount);
    assert_eq!(allowance_after.expiration, timestamp_after_upgrade);
    assert_eq!(allowance_after.nonce, nonce_before, "Nonce shouldn't change");
}


#[test]
#[fuzzer]
fn test_should_update_all(amount: u256, expiration: u64, mut nonce: u64) {
    nonce %= Bounded::MAX;
    let mut allowance_storage = setup();

    allowance_storage.update_all(amount, expiration, nonce);

    let timestamp_after = if expiration == 0 {
        starknet::get_block_timestamp()
    } else {
        expiration
    };
    let allowance_after = allowance_storage.read();

    assert_eq!(allowance_after.amount, amount);
    assert_eq!(allowance_after.expiration, timestamp_after);
    assert_eq!(allowance_after.nonce, nonce + 1);
}

#[test]
#[fuzzer]
fn test_should_pack_and_unpack(amount: u256, expiration: u64, mut nonce: u64) {
    let mut allowance_storage = setup();
    let expected_allowance = Allowance { amount, expiration, nonce };

    allowance_storage.write(expected_allowance);

    let stored_allowance = allowance_storage.read();
    assert_eq!(stored_allowance, expected_allowance, "Allowances does not match");
}
