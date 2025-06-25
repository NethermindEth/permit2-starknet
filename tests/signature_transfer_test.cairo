use core::num::traits::Bounded;
use openzeppelin_account::interface::AccountABIDispatcher;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use permit2::libraries::unordered_nonces::UnorderedNoncesComponent;
use permit2::mocks::mock_erc20::{IMintableDispatcher, IMintableDispatcherTrait};
use permit2::permit2::Permit2::SNIP12MetadataImpl;
use permit2::signature_transfer::interface::{
    ISignatureTransferDispatcher, ISignatureTransferDispatcherTrait, PermitBatchTransferFrom,
    PermitTransferFrom, SignatureTransferDetails, TokenPermissions,
};
use permit2::signature_transfer::snip12_utils::{
    PermitBatchTransferFromMessage, PermitTransferFromMessage, SNIP12HashWitnessTrait,
    TokenPermissionsStructHash,
};
use snforge_std::signature::stark_curve::StarkCurveSignerImpl;
use snforge_std::signature::SignerTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address_global,
    stop_cheat_block_timestamp, stop_cheat_caller_address_global,
};
use starknet::ContractAddress;
use crate::common::{Account, E18, INITIAL_SUPPLY, create_erc20_token, generate_account};

pub const DEFAULT_AMOUNT: u256 = E18;

#[derive(Drop, Copy)]
pub struct Setup {
    from: Account,
    to: Account,
    address_with_balance: ContractAddress,
    token0: IERC20Dispatcher,
    token1: IERC20Dispatcher,
    permit2: ISignatureTransferDispatcher,
}

fn setup() -> Setup {
    let permit2_contract = declare("Permit2").unwrap().contract_class();
    let (permit2_address, _) = permit2_contract
        .deploy(@array![])
        .expect('permit2 deployment failed');
    let permit2 = ISignatureTransferDispatcher { contract_address: permit2_address };
    let token0 = create_erc20_token(
        "Token 0",
        "TKN0",
        INITIAL_SUPPLY,
        starknet::get_contract_address(),
        starknet::get_contract_address(),
    );
    let token1 = create_erc20_token(
        "Token 1",
        "TKN1",
        INITIAL_SUPPLY,
        starknet::get_contract_address(),
        starknet::get_contract_address(),
    );

    let from = generate_account();
    let to = generate_account();
    let address_with_balance = 'ADDRESS_WITH_BALANCE'.try_into().unwrap();

    token0.transfer(from.account.contract_address, 100 * E18);
    token1.transfer(from.account.contract_address, 100 * E18);

    start_cheat_caller_address_global(from.account.contract_address);
    token0.approve(permit2_address, Bounded::MAX);
    token1.approve(permit2_address, Bounded::MAX);
    stop_cheat_caller_address_global();

    Setup { from, to, address_with_balance, token0, token1, permit2 }
}

#[test]
#[ignore]
fn test_correct_witness_type_hashes() {
    assert(true, '');
}

#[test]
fn test_permit_transfer_form() {
    let setup = setup();
    let this_address = starknet::get_contract_address();
    let nonce = 0;

    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };

    let permit_message = PermitTransferFromMessage {
        permitted: token_permission,
        spender: this_address,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let permit = PermitTransferFrom {
        permitted: token_permission,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_message.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    assert_eq!(end_balance_from, start_balance_from - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to, start_balance_to + DEFAULT_AMOUNT);
}

#[test]
#[should_panic(expected: 'Nonce already invalidated')]
fn test_should_panic_when_permit_transfer_from_when_invalid_nonce() {
    let setup = setup();
    let this_address = starknet::get_contract_address();
    let nonce = 0;

    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };

    let permit_message = PermitTransferFromMessage {
        permitted: token_permission,
        spender: this_address,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let permit = PermitTransferFrom {
        permitted: token_permission,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_message.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature.clone(),
        );
    /// Using invalidated nonce should panic
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
}

#[test]
#[fuzzer]
fn test_permit_transfer_from_random_nonce_and_amount(mut nonce: felt252, amount: u256) {
    let setup = setup();
    let this_address = starknet::get_contract_address();
    let (nonce_space, bit_pos) = UnorderedNoncesComponent::bitmap_positions(nonce);
    nonce = UnorderedNoncesComponent::pack_nonce(nonce_space, bit_pos % 251);

    IMintableDispatcher { contract_address: setup.token0.contract_address }
        .mint(setup.from.account.contract_address, amount);

    let token_permission = TokenPermissions { token: setup.token0.contract_address, amount };

    let permit_message = PermitTransferFromMessage {
        permitted: token_permission,
        spender: this_address,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let permit = PermitTransferFrom {
        permitted: token_permission,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_message.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: amount,
    };

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    assert_eq!(end_balance_from, start_balance_from - amount);
    assert_eq!(end_balance_to, start_balance_to + amount);
}

#[test]
#[fuzzer]
fn test_permit_transfer_spend_less_than_full(mut nonce: felt252, amount: u256) {
    let setup = setup();
    let this_address = starknet::get_contract_address();

    let (nonce_space, bit_pos) = UnorderedNoncesComponent::bitmap_positions(nonce);
    nonce = UnorderedNoncesComponent::pack_nonce(nonce_space, bit_pos % 251);

    IMintableDispatcher { contract_address: setup.token0.contract_address }
        .mint(setup.from.account.contract_address, amount);

    let token_permission = TokenPermissions { token: setup.token0.contract_address, amount };

    let permit_message = PermitTransferFromMessage {
        permitted: token_permission,
        spender: this_address,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let permit = PermitTransferFrom {
        permitted: token_permission,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_message.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let amount_to_spend = amount / 2;
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: amount_to_spend,
    };

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    assert_eq!(end_balance_from, start_balance_from - amount_to_spend);
    assert_eq!(end_balance_to, start_balance_to + amount_to_spend);
}

#[test]
fn test_permit_batch_transfer_from() {
    let setup = setup();
    let this_address = starknet::get_contract_address();
    let nonce = 0;

    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];

    let token_permissions = tokens.clone().into_iter().map(|token| TokenPermissions {
        token, amount: DEFAULT_AMOUNT,
    }).collect::<Array<_>>().span();
    
    let permit_message = PermitBatchTransferFromMessage {
        permitted: token_permissions,
        spender: this_address,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let permit = PermitBatchTransferFrom {
        permitted: token_permissions,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_message.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let transfer_details = array![
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        }, 
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        }, 
    ].span();

    let start_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let start_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );

    let end_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let end_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from0, start_balance_from0 - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to0, start_balance_to0 + DEFAULT_AMOUNT);
    assert_eq!(end_balance_from1, start_balance_from1 - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to1, start_balance_to1 + DEFAULT_AMOUNT);
}

#[test]
fn test_permit_batch_multi_permit_single_transfer() {
    let setup = setup();
    let this_address = starknet::get_contract_address();
    let nonce = 0;

    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];

    let token_permissions = tokens.clone().into_iter().map(|token| TokenPermissions {
        token, amount: DEFAULT_AMOUNT,
    }).collect::<Array<_>>().span();
    
    let permit_message = PermitBatchTransferFromMessage {
        permitted: token_permissions,
        spender: this_address,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let permit = PermitBatchTransferFrom {
        permitted: token_permissions,
        nonce,
        deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_message.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let transfer_details = array![
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: 0,
        }, 
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        }, 
    ].span();

    let start_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let start_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );

    let end_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let end_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from0, start_balance_from0);
    assert_eq!(end_balance_to0, start_balance_to0);
    assert_eq!(end_balance_from1, start_balance_from1 - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to1, start_balance_to1 + DEFAULT_AMOUNT);
}