use core::num::traits::Pow;
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use permit2::interfaces::signature_transfer::{
    ISignatureTransferDispatcherTrait, PermitBatchTransferFrom, PermitTransferFrom,
    SignatureTransferDetails, TokenPermissions,
};
use permit2::libraries::bitmap::{BitmapPackingTrait, MASK_8, SHIFT_8};
use permit2::permit2::Permit2::SNIP12MetadataImpl;
use permit2::snip12_utils::permits::{
    OffchainMessageHashWitnessTrait, PermitBatchStructHash, PermitBatchTransferFromStructHash,
    PermitBatchTransferFromStructHashWitness, PermitSingleStructHash, PermitTransferFromStructHash,
    PermitTransferFromStructHashWitness, TokenPermissionsStructHash,
};
use snforge_std::signature::SignerTrait;
use snforge_std::signature::stark_curve::StarkCurveSignerImpl;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_block_timestamp, start_cheat_caller_address,
    start_cheat_caller_address_global, stop_cheat_block_timestamp, stop_cheat_caller_address,
    stop_cheat_caller_address_global,
};
use starknet::get_block_timestamp;
use crate::common::E18;
use crate::mocks::interfaces::{IMintableDispatcher, IMintableDispatcherTrait};
use crate::mocks::mock_witness::{
    Beta, MockWitness, Zeta, _MOCK_WITNESS_TYPE_STRING, _WITNESS_TYPE_STRING_FULL,
};
use crate::setup::setupST as setup;
use crate::utils::mock_structs::make_witness;

pub const DEFAULT_AMOUNT: u256 = E18;

#[test]
fn test_permit_transfer_from() {
    let setup = setup();
    let mut spy = spy_events();
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: (get_block_timestamp() + 100).into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander calls `permit_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from, start_balance_from - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to, start_balance_to + DEFAULT_AMOUNT);

    spy
        .assert_emitted(
            @array![
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: DEFAULT_AMOUNT,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_permit_batch_transfer_from() {
    let setup = setup();
    let nonce = 0;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];

    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: 10 * E18 });
    };

    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (get_block_timestamp() + 100).into(),
    };
    let transfer_details = array![
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let start_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    // Bystander calls `permit_batch_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

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
#[should_panic(expected: 'Nonce already invalidated')]
fn test_should_panic_permit_transfer_from_nonce_already_invalidated() {
    let setup = setup();
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: (get_block_timestamp() + 100).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Bystander calls `permit_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature.clone(),
        );
    // Bystander tries to call `permit_transfer_from` again with the same nonce
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'Nonce already invalidated')]
fn test_should_panic_permit_batch_transfer_from_nonce_already_invalidated() {
    let setup = setup();
    let nonce = 0;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];

    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: 10 * E18 });
    };

    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (get_block_timestamp() + 100).into(),
    };
    let transfer_details = array![
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Bystander calls `permit_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature.clone(),
        );
    // Bystander tries to call `permit_transfer_from` again with the same nonce
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[fuzzer]
fn test_permit_transfer_from_random_nonce_and_amount(mut nonce: felt252, mut amount: u256) {
    let setup = setup();

    // A nonce's nonce space & bit position (bitmaps) are constrained, this limits them to only
    // valid bounds
    let nonce_u256: u256 = nonce.into();
    let _nonce_space = (nonce_u256 / SHIFT_8) % (2_u256.pow(243));
    let _bit_pos = (nonce_u256 & MASK_8) % 251;
    nonce = ((_nonce_space * SHIFT_8) + _bit_pos).try_into().unwrap();

    let (nonce_space, bit_pos) = BitmapPackingTrait::unpack_nonce(nonce);

    // Limit nonce to only valid bit_pos's
    nonce = BitmapPackingTrait::pack_nonce(nonce_space, bit_pos);

    // Limit amount to <= 1000 * E18
    //amount = amount % (99 * E18);
    let token_permission = TokenPermissions { token: setup.token0.contract_address, amount };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: (get_block_timestamp() + 100).into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: amount,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Owner tops up the `from` account with tokens
    start_cheat_caller_address(setup.token0.contract_address, setup.owner);
    IMintableDispatcher { contract_address: setup.token0.contract_address }
        .mint(setup.from.account.contract_address, amount);
    stop_cheat_caller_address(setup.token0.contract_address);

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander calls `permit_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_to, start_balance_to + amount);
    assert_eq!(end_balance_from, start_balance_from - amount);
}

#[test]
#[fuzzer]
fn test_permit_transfer_spend_less_than_full(mut nonce: felt252, amount: u256) {
    let setup = setup();

    // A nonce's nonce space & bit position (bitmaps) are constrained, this limits them to only
    // valid bounds
    let nonce_u256: u256 = nonce.into();
    let _nonce_space = (nonce_u256 / SHIFT_8) % (2_u256.pow(243));
    let _bit_pos = (nonce_u256 & MASK_8) % 251;
    nonce = ((_nonce_space * SHIFT_8) + _bit_pos).try_into().unwrap();

    let (nonce_space, bit_pos) = BitmapPackingTrait::unpack_nonce(nonce);

    nonce = BitmapPackingTrait::pack_nonce(nonce_space, bit_pos % 251);
    let amount_to_spend = amount / 2;
    let token_permission = TokenPermissions { token: setup.token0.contract_address, amount };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: (get_block_timestamp() + 100).into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: amount_to_spend,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Owner tops up the `from` account with tokens
    start_cheat_caller_address(setup.token0.contract_address, setup.owner);
    IMintableDispatcher { contract_address: setup.token0.contract_address }
        .mint(setup.from.account.contract_address, amount);
    stop_cheat_caller_address(setup.token0.contract_address);

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander calls `permit_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    assert_eq!(end_balance_from, start_balance_from - amount_to_spend);
    assert_eq!(end_balance_to, start_balance_to + amount_to_spend);
}

#[test]
fn test_permit_batch_tranfer_from_multi_permit_single_transfer() {
    let setup = setup();

    let nonce = 0;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];

    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };

    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (get_block_timestamp() + 100).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let start_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    // Bystander calls `permit_batch_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let end_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from0, start_balance_from0);
    assert_eq!(end_balance_to0, start_balance_to0);
    assert_eq!(end_balance_from1, start_balance_from1 - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to1, start_balance_to1 + DEFAULT_AMOUNT);
}

#[test]
fn test_permit_witness_transfer_from() {
    let setup = setup();
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: (get_block_timestamp() + 100).into(),
    };

    // Create a witness (struct hash)
    let witness = MockWitness {
        a: 1, b: Beta { b1: 2, b2: array![].span() }, z: Zeta { z1: 3, z2: array![].span() },
    }
        .hash_struct();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness, _MOCK_WITNESS_TYPE_STRING(),
        );
    stop_cheat_caller_address_global();
    // Sign the message hash
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander calls `permit_transfer_from`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_witness_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness,
            _MOCK_WITNESS_TYPE_STRING(),
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from, start_balance_from - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to, start_balance_to + DEFAULT_AMOUNT);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_transfer_from_with_invalid_signature_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    let message_hash = permit.get_message_hash(setup.to.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
}


#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_transfer_from_with_invalid_signature_length_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg, use incorrect sig length
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, _) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_transfer_from_with_invalid_signature_length_should_panic2() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg, use incorrect sig length
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s, 0];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: signature expired')]
fn test_permit_transfer_from_when_deadline_passed_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    start_cheat_block_timestamp(setup.permit2.contract_address, default_expiration + 1);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
    stop_cheat_block_timestamp(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_batch_transfer_from_with_invalid_signature_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };

    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign with `to  instead of `from`
    let message_hash = permit.get_message_hash(setup.to.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_batch_transfer_from_with_invalid_signature_length_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Mess with signature length
    let message_hash = permit.get_message_hash(setup.to.account.contract_address);
    let (r, _) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_batch_transfer_from_with_invalid_signature_length_should_panic2() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Mess with signature length
    let message_hash = permit.get_message_hash(setup.to.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: signature expired')]
fn test_permit_batch_transfer_from_when_deadline_passed_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    start_cheat_block_timestamp(setup.permit2.contract_address, default_expiration + 1);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
    stop_cheat_block_timestamp(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_transfer_from_with_invalid_spender_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    // To address tries to use bystanders permit
    start_cheat_caller_address(setup.permit2.contract_address, setup.to.account.contract_address);
    setup
        .permit2
        .permit_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_batch_transfer_with_invalid_spender_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    // To address tries to use bystanders permit
    start_cheat_caller_address(setup.permit2.contract_address, setup.to.account.contract_address);
    setup
        .permit2
        .permit_batch_transfer_from(
            permit, transfer_details, setup.from.account.contract_address, signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_witness_transfer_from_with_invalid_spender_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };
    let witness = make_witness();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness.hash_struct(), _WITNESS_TYPE_STRING_FULL(),
        );
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    // To address tries to use bystanders permit
    start_cheat_caller_address(setup.permit2.contract_address, setup.to.account.contract_address);
    setup
        .permit2
        .permit_witness_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness.hash_struct(),
            _WITNESS_TYPE_STRING_FULL(),
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_witness_transfer_from_with_invalid_witness_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };
    let mut witness = make_witness();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness.hash_struct(), _WITNESS_TYPE_STRING_FULL(),
        );
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    stop_cheat_caller_address_global();

    // Invalid witness
    witness.a += 1;
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_witness_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness.hash_struct(),
            _WITNESS_TYPE_STRING_FULL(),
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_witness_transfer_from_with_invalid_witness_type_string_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let nonce = 0;
    let token_permission = TokenPermissions {
        token: setup.token0.contract_address, amount: 10 * E18,
    };
    let permit = PermitTransferFrom {
        permitted: token_permission, nonce, deadline: default_expiration.into(),
    };
    let transfer_details = SignatureTransferDetails {
        to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
    };
    let witness = make_witness();
    let mut witness_type_string = _WITNESS_TYPE_STRING_FULL();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness.hash_struct(), witness_type_string.clone(),
        );
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    stop_cheat_caller_address_global();

    // Invalid witness type string
    witness_type_string.append(@" ");
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_witness_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness.hash_struct(),
            witness_type_string,
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_batch_witness_transfer_with_invalid_spender_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };
    let witness = make_witness();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness.hash_struct(), _WITNESS_TYPE_STRING_FULL(),
        );
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    // To address tries to use bystanders permit
    start_cheat_caller_address(setup.permit2.contract_address, setup.to.account.contract_address);
    setup
        .permit2
        .permit_witness_batch_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness.hash_struct(),
            _WITNESS_TYPE_STRING_FULL(),
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_witness_batch_transfer_from_with_invalid_witness_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };
    let mut witness = make_witness();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness.hash_struct(), _WITNESS_TYPE_STRING_FULL(),
        );
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    // Invalid witness
    witness.a += 1;
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_witness_batch_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness.hash_struct(),
            _WITNESS_TYPE_STRING_FULL(),
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'ST: invalid signature')]
fn test_permit_witness_batch_transfer_from_with_invalid_witness_type_string_should_panic() {
    let setup = setup();
    let nonce = 0;
    let default_expiration = get_block_timestamp() + 5;
    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let mut token_permissions: Array<TokenPermissions> = array![];
    for token in tokens.span() {
        token_permissions.append(TokenPermissions { token: *token, amount: DEFAULT_AMOUNT });
    };
    let transfer_details = array![
        // Transfer 0 tokens
        SignatureTransferDetails { to: setup.to.account.contract_address, requested_amount: 0 },
        // Transer some tokens
        SignatureTransferDetails {
            to: setup.to.account.contract_address, requested_amount: DEFAULT_AMOUNT,
        },
    ]
        .span();
    let permit = PermitBatchTransferFrom {
        permitted: token_permissions.span(), nonce, deadline: (default_expiration).into(),
    };
    let witness = make_witness();
    let mut witness_type_string = _WITNESS_TYPE_STRING_FULL();

    // Hashing uses the caller's address, so we must mock it here
    start_cheat_caller_address_global(setup.bystander);
    // Sign msg
    let message_hash = permit
        .get_message_hash_with_witness(
            setup.from.account.contract_address, witness.hash_struct(), witness_type_string.clone(),
        );
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    stop_cheat_caller_address_global();

    // Invalid witness
    witness_type_string.append(@"a");
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .permit_witness_batch_transfer_from(
            permit,
            transfer_details,
            setup.from.account.contract_address,
            witness.hash_struct(),
            witness_type_string,
            signature,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}

