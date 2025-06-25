use core::num::traits::Bounded;
use openzeppelin_account::interface::AccountABIDispatcher;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use permit2::allowance_transfer::interface::{
    AllowanceTransferDetails, IAllowanceTransferDispatcher, IAllowanceTransferDispatcherTrait,
    PermitBatch, PermitDetails, PermitSingle, TokenSpenderPair, events,
};
use permit2::allowance_transfer::snip12_utils::{
    PermitBatchStructHash, PermitDetailsStructHash, PermitSingleStructHash,
};
use permit2::permit2::Permit2::SNIP12MetadataImpl;
use snforge_std::signature::stark_curve::{
    StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
};
use snforge_std::signature::{KeyPair, KeyPairTrait, SignerTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, start_cheat_caller_address_global,
    stop_cheat_block_timestamp, stop_cheat_caller_address, stop_cheat_caller_address_global,
};
use starknet::ContractAddress;
use crate::common::{Account, E18, INITIAL_SUPPLY, create_erc20_token, generate_account};

#[derive(Drop, Copy)]
pub struct Setup {
    from: Account,
    to: Account,
    address_with_balance: ContractAddress,
    token0: IERC20Dispatcher,
    token1: IERC20Dispatcher,
    permit2: IAllowanceTransferDispatcher,
}

const DEFAULT_AMOUNT: u256 = 30 * E18;
const DEFAULT_NONCE: u64 = 0;

fn setup() -> Setup {
    let permit2_contract = declare("Permit2").unwrap().contract_class();
    let (permit2_address, _) = permit2_contract
        .deploy(@array![])
        .expect('permit2 deployment failed');
    let permit2 = IAllowanceTransferDispatcher { contract_address: permit2_address };
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

    token0.transfer(to.account.contract_address, 100 * E18);
    token1.transfer(to.account.contract_address, 100 * E18);

    token0.transfer(address_with_balance, DEFAULT_AMOUNT);
    token1.transfer(address_with_balance, DEFAULT_AMOUNT);

    start_cheat_caller_address_global(from.account.contract_address);
    token0.approve(permit2_address, Bounded::MAX);
    token1.approve(permit2_address, Bounded::MAX);
    stop_cheat_caller_address_global();

    start_cheat_caller_address_global(to.account.contract_address);
    token0.approve(permit2_address, Bounded::MAX);
    token1.approve(permit2_address, Bounded::MAX);
    /// TODO: Might not be necessary if warm storage slot does not matter, seems lıke solidity has
    /// for benchmarking.
    //permit2.invalidate_nonces(token0.contract_address, starknet::get_contract_address(), 1);
    //permit2.invalidate_nonces(token1.contract_address, starknet::get_contract_address(), 1);
    stop_cheat_caller_address_global();

    Setup { from, to, address_with_balance, token0, token1, permit2 }
}

#[test]
fn test_should_approve() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let mut spy = spy_events();
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup
        .permit2
        .approve(
            setup.token0.contract_address,
            starknet::get_contract_address(),
            DEFAULT_AMOUNT,
            default_expiration,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 0);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::Approval(
                        events::Approval {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: starknet::get_contract_address(),
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_should_set_allowance() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);
}

#[test]
#[ignore]
fn test_should_set_allowance_dirty_write() {}

// Account Abstraction
//#[test]
//#[ignore]
//fn test_should_set_allowance_compact_sig() {}

// Account Abstraction
//#[test]
//#[ignore]
//fn test_should_set_allowance_incorrect_sig_length() {}

#[test]
fn test_should_set_allowance_batch_different_nonces() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);

    let details = array![
        PermitDetails {
            token: setup.token0.contract_address,
            amount: DEFAULT_AMOUNT,
            expiration: default_expiration,
            nonce: 1,
        },
        PermitDetails {
            token: setup.token1.contract_address,
            amount: DEFAULT_AMOUNT,
            expiration: default_expiration,
            nonce: DEFAULT_NONCE,
        },
    ]
        .span();

    let permit_batch = PermitBatch {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 2);

    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token1.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount1, DEFAULT_AMOUNT);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);
}

#[test]
fn test_set_allowance_batch() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = array![
        PermitDetails {
            token: setup.token0.contract_address,
            amount: DEFAULT_AMOUNT,
            expiration: default_expiration,
            nonce: DEFAULT_NONCE,
        },
        PermitDetails {
            token: setup.token1.contract_address,
            amount: DEFAULT_AMOUNT,
            expiration: default_expiration,
            nonce: DEFAULT_NONCE,
        },
    ]
        .span();

    let permit_batch = PermitBatch {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);

    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token1.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount1, DEFAULT_AMOUNT);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);
}


#[test]
fn test_set_allowance_batch_should_emit_event() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = array![
        PermitDetails {
            token: setup.token0.contract_address,
            amount: DEFAULT_AMOUNT,
            expiration: default_expiration,
            nonce: DEFAULT_NONCE,
        },
        PermitDetails {
            token: setup.token1.contract_address,
            amount: DEFAULT_AMOUNT,
            expiration: default_expiration,
            nonce: DEFAULT_NONCE,
        },
    ]
        .span();

    let permit_batch = PermitBatch {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let mut spy = spy_events();
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::Permit(
                        events::Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: starknet::get_contract_address(),
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::Permit(
                        events::Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token1.contract_address,
                            spender: starknet::get_contract_address(),
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_set_allowance_transfer() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);

    setup
        .permit2
        .transfer_from(
            setup.from.account.contract_address,
            setup.to.account.contract_address,
            DEFAULT_AMOUNT,
            setup.token0.contract_address,
        );
    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    assert_eq!(end_balance_from, start_balance_from - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to, start_balance_to + DEFAULT_AMOUNT);
}


#[test]
fn test_batch_transfer_from() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);

    let transfer_details = (0..3_u8)
        .into_iter()
        .map(
            |_x| {
                AllowanceTransferDetails {
                    from: setup.from.account.contract_address,
                    to: setup.to.account.contract_address,
                    amount: E18,
                    token: setup.token0.contract_address,
                }
            },
        )
        .collect::<Array<_>>();
    setup.permit2.batch_transfer_from(transfer_details.clone());
    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    let total_transferred = transfer_details.len().into() * E18;
    assert_eq!(end_balance_from, start_balance_from - total_transferred);
    assert_eq!(end_balance_to, start_balance_to + total_transferred);
}

#[test]
#[should_panic(expect: 'InvalidSignature')]
fn test_should_set_allowance_invalid_signature() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let mut permit = PermitSingle {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    permit.spender = setup.to.account.contract_address;
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
}

#[test]
#[should_panic(expect: 'SignatureExpired')]
fn test_should_panic_when_set_allowance_when_deadline_passed() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details, spender: starknet::get_contract_address(), sig_deadline: default_expiration.into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    start_cheat_block_timestamp(setup.permit2.contract_address, default_expiration + 1);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_block_timestamp(setup.permit2.contract_address);
}

#[test]
fn test_max_allowance() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;
    let max_allowance = Bounded::MAX;
    let this_address = starknet::get_contract_address();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: max_allowance,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details, spender: this_address, sig_deadline: default_expiration.into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    setup.permit2.permit(setup.from.account.contract_address, permit, signature);

    let (start_allowed_amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(start_allowed_amount, Bounded::MAX);

    setup
        .permit2
        .transfer_from(
            setup.from.account.contract_address,
            setup.to.account.contract_address,
            DEFAULT_AMOUNT,
            setup.token0.contract_address,
        );

    let (end_allowed_amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(end_allowed_amount, Bounded::MAX);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from, start_balance_from - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to, start_balance_to + DEFAULT_AMOUNT);
}


#[test]
fn test_partial_allowance() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;
    let this_address = starknet::get_contract_address();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details, spender: this_address, sig_deadline: default_expiration.into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    setup.permit2.permit(setup.from.account.contract_address, permit, signature);

    let (start_allowed_amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(start_allowed_amount, DEFAULT_AMOUNT);

    let transfer_amount = 5 * E18;
    setup
        .permit2
        .transfer_from(
            setup.from.account.contract_address,
            setup.to.account.contract_address,
            transfer_amount,
            setup.token0.contract_address,
        );

    let (end_allowed_amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(end_allowed_amount, DEFAULT_AMOUNT - transfer_amount);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from, start_balance_from - transfer_amount);
    assert_eq!(end_balance_to, start_balance_to + transfer_amount);
}

#[test]
#[should_panic(expected: 'InvalidNonce')]
fn test_should_panic_when_reuse_ordered_nonce() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;
    let this_address = starknet::get_contract_address();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details, spender: this_address, sig_deadline: default_expiration.into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    setup.permit2.permit(setup.from.account.contract_address, permit, signature.clone());

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(nonce, 1);
    assert_eq!(expiration, default_expiration);
    assert_eq!(amount, DEFAULT_AMOUNT);

    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
}

#[test]
fn test_should_invalidate_nonces() {
    let setup = setup();
    let this_address = starknet::get_contract_address();

    let mut spy = spy_events();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, this_address, 1);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (_, _, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(nonce, 1);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::NonceInvalidation(
                        events::NonceInvalidation {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: this_address,
                            new_nonce: 1,
                            old_nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_should_invalidate_multiple_nonces() {
    let setup = setup();
    let this_address = starknet::get_contract_address();

    let mut spy = spy_events();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, this_address, 33);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (_, _, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );
    assert_eq!(nonce, 33);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::NonceInvalidation(
                        events::NonceInvalidation {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: this_address,
                            new_nonce: 33,
                            old_nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expect: 'InvalidNonce')]
fn test_should_spanic_when_invalidating_already_invalid_nonces() {
    let setup = setup();
    let this_address = starknet::get_contract_address();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, this_address, DEFAULT_NONCE);
    /// Invalidating already invalid nocnce should panic.
    setup.permit2.invalidate_nonces(setup.token0.contract_address, this_address, DEFAULT_NONCE);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expect: 'ExcessiveInvalidation')]
fn test_should_spanic_when_invalidating_excessive_amount_of_nonces() {
    let setup = setup();
    let this_address = starknet::get_contract_address();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup
        .permit2
        .invalidate_nonces(setup.token0.contract_address, this_address, Bounded::<u16>::MAX.into());
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
fn test_should_batch_transfer_from_multi_token() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;

    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let details = tokens
        .clone()
        .into_iter()
        .map(
            |token| {
                PermitDetails {
                    token,
                    amount: DEFAULT_AMOUNT,
                    expiration: default_expiration,
                    nonce: DEFAULT_NONCE,
                }
            },
        )
        .collect::<Array<_>>()
        .span();

    let permit_batch = PermitBatch {
        details,
        spender: starknet::get_contract_address(),
        sig_deadline: (starknet::get_block_timestamp() + 100).into(),
    };

    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let start_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT);

    let (amount1, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token1.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount1, DEFAULT_AMOUNT);

    let transfer_details = tokens
        .into_iter()
        .map(
            |token| {
                AllowanceTransferDetails {
                    from: setup.from.account.contract_address,
                    to: setup.to.account.contract_address,
                    amount: E18,
                    token,
                }
            },
        )
        .collect::<Array<_>>();

    setup.permit2.batch_transfer_from(transfer_details.clone());

    let end_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let end_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);
    assert_eq!(end_balance_from0, start_balance_from0 - E18);
    assert_eq!(end_balance_to0, start_balance_to0 + E18);
    assert_eq!(end_balance_from1, start_balance_from1 - E18);
    assert_eq!(end_balance_to1, start_balance_to1 + E18);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT - E18);

    let (amount1, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token1.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount1, DEFAULT_AMOUNT - E18);
}


#[test]
fn test_should_batch_transfer_from_different_owners() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;
    let this_address = starknet::get_contract_address();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };

    let permit = PermitSingle {
        details, spender: this_address, sig_deadline: default_expiration.into(),
    };

    let message_hash_from = permit.get_message_hash(setup.from.account.contract_address);
    let message_hash_to = permit.get_message_hash(setup.to.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash_from).unwrap();
    let signature_from = array![r, s];

    let (r, s) = setup.to.key_pair.sign(message_hash_to).unwrap();
    let signature_to = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_recepient = setup.token0.balance_of(this_address);

    setup.permit2.permit(setup.from.account.contract_address, permit, signature_from);
    setup.permit2.permit(setup.to.account.contract_address, permit, signature_to);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );

    assert_eq!(amount, DEFAULT_AMOUNT);

    let (amount1, _, _) = setup
        .permit2
        .allowance(setup.to.account.contract_address, setup.token0.contract_address, this_address);

    assert_eq!(amount1, DEFAULT_AMOUNT);

    let owners = array![setup.from.account.contract_address, setup.to.account.contract_address];
    let transfer_details = owners
        .into_iter()
        .map(
            |owner| {
                AllowanceTransferDetails {
                    from: owner,
                    to: this_address,
                    amount: E18,
                    token: setup.token0.contract_address,
                }
            },
        )
        .collect::<Array<_>>();

    setup.permit2.batch_transfer_from(transfer_details.clone());

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_recepient = setup.token0.balance_of(this_address);

    assert_eq!(end_balance_from, start_balance_from - E18);
    assert_eq!(end_balance_to, start_balance_to - E18);
    assert_eq!(end_balance_recepient, start_balance_recepient + 2 * E18);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount, DEFAULT_AMOUNT - E18);

    let (amount1, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address,
            setup.token0.contract_address,
            starknet::get_contract_address(),
        );

    assert_eq!(amount1, DEFAULT_AMOUNT - E18);
}


#[test]
fn test_lockdown() {
    let setup = setup();
    let default_expiration = starknet::get_block_timestamp() + 5;
    let this_address = starknet::get_contract_address();

    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];
    let details = tokens
        .clone()
        .into_iter()
        .map(
            |token| {
                PermitDetails {
                    token,
                    amount: DEFAULT_AMOUNT,
                    expiration: default_expiration,
                    nonce: DEFAULT_NONCE,
                }
            },
        )
        .collect::<Array<_>>()
        .span();

    let permit_batch = PermitBatch {
        details, spender: this_address, sig_deadline: default_expiration.into(),
    };

    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);

    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token1.contract_address, this_address,
        );

    assert_eq!(amount1, DEFAULT_AMOUNT);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);

    let approvals = tokens
        .into_iter()
        .map(|token| {
            TokenSpenderPair { token, spender: this_address }
        })
        .collect::<Array<_>>();

    let mut spy = spy_events();
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.lockdown(approvals);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, this_address,
        );

    assert_eq!(amount, 0);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);

    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token1.contract_address, this_address,
        );

    assert_eq!(amount1, 0);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::Lockdown(
                        events::Lockdown {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: this_address,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    events::AllowanceTransferEvent::Lockdown(
                        events::Lockdown {
                            owner: setup.from.account.contract_address,
                            token: setup.token1.contract_address,
                            spender: this_address,
                        },
                    ),
                ),
            ],
        );
}
