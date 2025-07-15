use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use permit2::interfaces::permit2::{IPermit2Dispatcher, IPermit2DispatcherTrait};
use snforge_std::{start_cheat_chain_id_global, stop_cheat_chain_id_global};
use starknet::get_tx_info;
use crate::setup::deploy_permit2;

const STARKNET_DOMAIN_TYPE_HASH: felt252 = selector!(
    "\"StarknetDomain\"(\"name\":\"shortstring\",\"version\":\"shortstring\",\"chainId\":\"shortstring\",\"revision\":\"shortstring\")",
);
const NAME: felt252 = 'Permit2';
const VERSION: felt252 = 'v1';
const REVISION: felt252 = 1;


#[test]
fn test_domain_seperator() {
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
fn test_domain_seperator_after_fork() {
    let permit2 = IPermit2Dispatcher { contract_address: deploy_permit2() };
    let begenning_seperator = permit2.DOMAIN_SEPARATOR();
    let new_chain_id = get_tx_info().unbox().chain_id + 1;

    start_cheat_chain_id_global(new_chain_id);
    let expected = PoseidonTrait::new()
        .update_with(STARKNET_DOMAIN_TYPE_HASH)
        .update_with(NAME)
        .update_with(VERSION)
        .update_with(new_chain_id)
        .update_with(REVISION)
        .finalize();

    assert_ne!(begenning_seperator, permit2.DOMAIN_SEPARATOR());
    assert_eq!(permit2.DOMAIN_SEPARATOR(), expected);

    stop_cheat_chain_id_global();
}
