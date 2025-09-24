use core::num::traits::Bounded;
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use permit2::components::allowance_transfer::AllowanceTransferComponent;
use permit2::components::allowance_transfer::AllowanceTransferComponent::{
    Approval, Lockdown, NonceInvalidation, Permit,
};
use permit2::interfaces::allowance_transfer::{
    AllowanceTransferDetails, IAllowanceTransferDispatcherTrait, PermitBatch, PermitDetails,
    PermitSingle, TokenSpenderPair,
};
use permit2::permit2::Permit2::SNIP12MetadataImpl;
use permit2::snip12_utils::permits::{
    PermitBatchStructHash, PermitDetailsStructHash, PermitSingleStructHash,
};
use snforge_std::signature::SignerTrait;
use snforge_std::signature::stark_curve::{
    StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
};
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_block_timestamp, start_cheat_caller_address,
    stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::get_block_timestamp;
use crate::common::E18;
use crate::setup::setupAT as setup;

const DEFAULT_AMOUNT: u256 = 30 * E18;
const DEFAULT_NONCE: u64 = 0;

#[test]
fn test_approve_sets_allowance() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

    // From approves bystander to spend `DEFAULT_AMOUNT` of `token0` on their behalf
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup
        .permit2
        .approve(
            setup.token0.contract_address, setup.bystander, DEFAULT_AMOUNT, default_expiration,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 0);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Approval(
                        Approval {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_approve_overrides_previous_allowance() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

    // From approves bystander to spend `DEFAULT_AMOUNT` of `token0` on their behalf
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup
        .permit2
        .approve(
            setup.token0.contract_address, setup.bystander, DEFAULT_AMOUNT, default_expiration,
        );
    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 0); // unchanged

    // From approves bystander to spend `DEFAULT_AMOUNT` + 1 of `token0` on their behalf
    setup
        .permit2
        .approve(
            setup.token0.contract_address,
            setup.bystander,
            DEFAULT_AMOUNT + 1,
            default_expiration + 1,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT + 1);
    assert_eq!(expiration, default_expiration + 1);
    assert_eq!(nonce, 0); // unchanged

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Approval(
                        Approval {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Approval(
                        Approval {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT + 1,
                            expiration: default_expiration + 1,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_permit_sets_allowance() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    // From signs the message
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Bystander uses permit to approve bystander to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    // behalf
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
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
fn test_permit_batch_sets_allowances() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

    // From approves bystander to spend `DEFAULT_AMOUNT` of `token0` on their behalf
    let permit_details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details: permit_details,
        spender: setup.bystander,
        sig_deadline: (get_block_timestamp() + 100).into(),
    };
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);

    // From approves bystander to spend `DEFAULT_AMOUNT` of `token0` & `token1` on their behalf
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
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };
    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 2);

    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token1.contract_address, setup.bystander,
        );

    assert_eq!(amount1, DEFAULT_AMOUNT);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE + 1,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token1.contract_address,
                            spender: setup.bystander,
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
fn test_permit_allowance_transfer() {
    let setup = setup();
    let mut spy = spy_events();

    let default_expiration = get_block_timestamp() + 5;
    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash and sign the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander uses permit to approve `from` to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    // Bystander transfers `DEFAULT_AMOUNT` of `token0` from `from` to `to`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .transfer_from(
            setup.from.account.contract_address,
            setup.to.account.contract_address,
            DEFAULT_AMOUNT,
            setup.token0.contract_address,
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
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
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
fn test_permit_batch_allowance_transfer_same_token() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash and sign permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander uses permit to approve `from` to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT);

    // Batch transfer details (transfer token0 multiple times)
    let mut transfer_details: Array<AllowanceTransferDetails> = array![];
    let mut i = 0_u8;
    while i != 3 {
        transfer_details
            .append(
                AllowanceTransferDetails {
                    from: setup.from.account.contract_address,
                    to: setup.to.account.contract_address,
                    amount: E18,
                    token: setup.token0.contract_address,
                },
            );

        i += 1;
    };

    // Bystander transfers `E18` of `token0` from `from` to `to` multiple times
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.batch_transfer_from(transfer_details.clone());
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    let total_transferred = transfer_details.len().into() * E18;
    assert_eq!(end_balance_from, start_balance_from - total_transferred);
    assert_eq!(end_balance_to, start_balance_to + total_transferred);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
    spy
        .assert_emitted(
            @array![
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_permit_batch_allowance_transfer_different_tokens() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

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
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash and sign permit message
    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let start_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    // Bystander uses permit to approve `from` to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    let (amount2, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token1.contract_address, setup.bystander,
        );

    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(amount2, DEFAULT_AMOUNT);

    // Batch transfer details (transfer token0 & token1 multiple times each)
    let mut transfer_details = array![];
    for _i in 0..3_u8 {
        transfer_details
            .append(
                AllowanceTransferDetails {
                    from: setup.from.account.contract_address,
                    to: setup.to.account.contract_address,
                    amount: E18,
                    token: setup.token0.contract_address,
                },
            );

        transfer_details
            .append(
                AllowanceTransferDetails {
                    from: setup.from.account.contract_address,
                    to: setup.to.account.contract_address,
                    amount: E18,
                    token: setup.token1.contract_address,
                },
            );
    };

    // Bystander transfers `E18` of `token0` & `token1` from `from` to `to` multiple times
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.batch_transfer_from(transfer_details.clone());
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from0 = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to0 = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_from1 = setup.token1.balance_of(setup.from.account.contract_address);
    let end_balance_to1 = setup.token1.balance_of(setup.to.account.contract_address);

    let total_transferred = 3 * E18;

    assert_eq!(end_balance_from0, start_balance_from0 - total_transferred);
    assert_eq!(end_balance_to0, start_balance_to0 + total_transferred);
    assert_eq!(end_balance_from1, start_balance_from1 - total_transferred);
    assert_eq!(end_balance_to1, start_balance_to1 + total_transferred);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token1.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
    spy
        .assert_emitted(
            @array![
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token1.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token1.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token1.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.to.account.contract_address,
                            value: E18,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'AT: invalid signature')]
fn test_permit_with_invalid_signature_should_fail() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let mut permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    permit.spender = setup.to.account.contract_address; // change spender post-hashing
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
}

#[test]
#[should_panic(expected: 'AT: signature expired')]
fn test_permit_when_deadline_passed_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: default_expiration.into(),
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
    let default_expiration = get_block_timestamp() + 5;
    let max_allowance = Bounded::MAX;

    // Permit max allowance
    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: max_allowance,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: default_expiration.into(),
    };

    // Hash and sign the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander uses permit to approve `from` to spend `max_allowance` of `token0` on
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (allowance_amount_start, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(allowance_amount_start, Bounded::MAX);

    // Bystander transfers `DEFAULT_AMOUNT` of `token0` from `from` to `to`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup
        .permit2
        .transfer_from(
            setup.from.account.contract_address,
            setup.to.account.contract_address,
            DEFAULT_AMOUNT,
            setup.token0.contract_address,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (allowance_amount_end, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(allowance_amount_end, Bounded::MAX);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from, start_balance_from - DEFAULT_AMOUNT);
    assert_eq!(end_balance_to, start_balance_to + DEFAULT_AMOUNT);
}

#[test]
fn test_partial_allowance() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: default_expiration.into(),
    };

    // Hash and sign the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    // Bystander uses permit to approve `from` to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);

    let (allowance_amount_start, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(allowance_amount_start, DEFAULT_AMOUNT);

    // Bystander transfers `DEFAULT_AMOUNT / 5` of `token0` from `from` to `to`
    let transfer_amount = DEFAULT_AMOUNT / 5;
    setup
        .permit2
        .transfer_from(
            setup.from.account.contract_address,
            setup.to.account.contract_address,
            transfer_amount,
            setup.token0.contract_address,
        );
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (allowance_amount_end, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(allowance_amount_end, DEFAULT_AMOUNT - transfer_amount);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);

    assert_eq!(end_balance_from, start_balance_from - transfer_amount);
    assert_eq!(end_balance_to, start_balance_to + transfer_amount);
}

#[test]
#[should_panic(expected: 'AT: invalid nonce')]
fn test_permit_should_panic_when_ordered_nonce_reused() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: default_expiration.into(),
    };

    let message_hash = permit.get_message_hash(setup.from.account.contract_address);

    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Bystander uses permit to approve `from` to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature.clone());
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(nonce, 1);
    assert_eq!(expiration, default_expiration);
    assert_eq!(amount, DEFAULT_AMOUNT);

    // Bystander tries to use the same permit to approve `from` to spend `DEFAULT_AMOUNT` of
    // `token0` on `from`s
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
fn test_invalidate_single_nonce() {
    let setup = setup();

    let mut spy = spy_events();

    let (_, _, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(nonce, 0);

    // Set new nonce to 1 (+=1)
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, setup.bystander, 1);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (_, _, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(nonce, 1);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::NonceInvalidation(
                        NonceInvalidation {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            new_nonce: 1,
                            old_nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_invalidate_multiple_nonces_and_events() {
    let setup = setup();

    let mut spy = spy_events();

    let (_, _, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(nonce, 0);

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, setup.bystander, 33);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (_, _, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(nonce, 33);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::NonceInvalidation(
                        NonceInvalidation {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            new_nonce: 33,
                            old_nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'AT: invalid nonce')]
fn test_invalidate_already_used_nonce_should_panic() {
    let setup = setup();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, setup.bystander, 10);
    /// Invalidating already invalid nonce should panic.
    setup.permit2.invalidate_nonces(setup.token0.contract_address, setup.bystander, 10);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'AT: invalid nonce')]
fn test_invalidate_already_used_nonce_should_panic2() {
    let setup = setup();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.invalidate_nonces(setup.token0.contract_address, setup.bystander, 10);
    /// Invalidating already invalid nonce should panic.
    setup.permit2.invalidate_nonces(setup.token0.contract_address, setup.bystander, 9);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'AT: invalid nonce')]
fn test_must_use_current_nonce() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE + 1,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    // From signs the message
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Bystander uses permit to approve bystander to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    // behalf
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'AT: excessive nonce delta')]
fn test_invalidating_excessive_amount_of_nonces_should_panic() {
    let setup = setup();

    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup
        .permit2
        .invalidate_nonces(
            setup.token0.contract_address, setup.bystander, Bounded::<u16>::MAX.into(),
        );
    stop_cheat_caller_address(setup.permit2.contract_address);
}


#[test]
fn test_batch_transfer_from_different_owners() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;
    let mut spy = spy_events();

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: default_expiration.into(),
    };

    let message_hash_from = permit.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash_from).unwrap();
    let signature_from = array![r, s];

    let message_hash_to = permit.get_message_hash(setup.to.account.contract_address);
    let (r, s) = setup.to.key_pair.sign(message_hash_to).unwrap();
    let signature_to = array![r, s];

    let start_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let start_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    let start_balance_recipient = setup.token0.balance_of(setup.bystander);

    // Bystander uses permit to approve `from` and `to` to spend `DEFAULT_AMOUNT` of `token0`
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature_from);
    setup.permit2.permit(setup.to.account.contract_address, permit, signature_to);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT);

    let (amount1, _, _) = setup
        .permit2
        .allowance(
            setup.to.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount1, DEFAULT_AMOUNT);

    let owners = array![setup.from.account.contract_address, setup.to.account.contract_address];
    let mut transfer_details = array![];
    for owner in owners.span() {
        transfer_details
            .append(
                AllowanceTransferDetails {
                    from: *owner,
                    to: setup.bystander,
                    amount: E18,
                    token: setup.token0.contract_address,
                },
            );
    };

    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.batch_transfer_from(transfer_details.clone());
    stop_cheat_caller_address(setup.permit2.contract_address);

    let end_balance_from = setup.token0.balance_of(setup.from.account.contract_address);
    let end_balance_to = setup.token0.balance_of(setup.to.account.contract_address);
    let end_balance_recipient = setup.token0.balance_of(setup.bystander);

    assert_eq!(end_balance_from, start_balance_from - E18);
    assert_eq!(end_balance_to, start_balance_to - E18);
    assert_eq!(end_balance_recipient, start_balance_recipient + 2 * E18);

    let (amount, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );

    assert_eq!(amount, DEFAULT_AMOUNT - E18);

    let (amount1, _, _) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );

    assert_eq!(amount1, DEFAULT_AMOUNT - E18);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Permit(
                        Permit {
                            owner: setup.to.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                            amount: DEFAULT_AMOUNT,
                            expiration: default_expiration,
                            nonce: DEFAULT_NONCE,
                        },
                    ),
                ),
            ],
        );
    spy
        .assert_emitted(
            @array![
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.from.account.contract_address,
                            to: setup.bystander,
                            value: E18,
                        },
                    ),
                ),
                (
                    setup.token0.contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: setup.to.account.contract_address,
                            to: setup.bystander,
                            value: E18,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_lockdown() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let tokens = array![setup.token0.contract_address, setup.token1.contract_address];

    let mut details = array![];
    for token in tokens.span() {
        details
            .append(
                PermitDetails {
                    token: *token,
                    amount: DEFAULT_AMOUNT,
                    expiration: default_expiration,
                    nonce: DEFAULT_NONCE,
                },
            );
    };

    let permit_batch = PermitBatch {
        details: details.span(), spender: setup.bystander, sig_deadline: default_expiration.into(),
    };
    let message_hash = permit_batch.get_message_hash(setup.from.account.contract_address);
    let (r, s) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s];

    // Permit batch
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.permit_batch(setup.from.account.contract_address, permit_batch, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, DEFAULT_AMOUNT);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);
    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token1.contract_address, setup.bystander,
        );
    assert_eq!(amount1, DEFAULT_AMOUNT);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);

    // Build token spender pairs
    let mut approvals = array![];
    for token in tokens.span() {
        approvals.append(TokenSpenderPair { token: *token, spender: setup.bystander });
    };

    let mut spy = spy_events();

    // Lockdown
    start_cheat_caller_address(setup.permit2.contract_address, setup.from.account.contract_address);
    setup.permit2.lockdown(approvals);
    stop_cheat_caller_address(setup.permit2.contract_address);

    let (amount, expiration, nonce) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token0.contract_address, setup.bystander,
        );
    assert_eq!(amount, 0);
    assert_eq!(expiration, default_expiration);
    assert_eq!(nonce, 1);
    let (amount1, expiration1, nonce1) = setup
        .permit2
        .allowance(
            setup.from.account.contract_address, setup.token1.contract_address, setup.bystander,
        );
    assert_eq!(amount1, 0);
    assert_eq!(expiration1, default_expiration);
    assert_eq!(nonce1, 1);

    spy
        .assert_emitted(
            @array![
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Lockdown(
                        Lockdown {
                            owner: setup.from.account.contract_address,
                            token: setup.token0.contract_address,
                            spender: setup.bystander,
                        },
                    ),
                ),
                (
                    setup.permit2.contract_address,
                    AllowanceTransferComponent::Event::Lockdown(
                        Lockdown {
                            owner: setup.from.account.contract_address,
                            token: setup.token1.contract_address,
                            spender: setup.bystander,
                        },
                    ),
                ),
            ],
        );
}

//// Account Abstraction
#[test]
#[should_panic(expected: 'AT: invalid signature')]
fn test_permit_incorrect_sig_length_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    // Mess with sig length
    let (r, s): (felt252, felt252) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s, 0]; // Add an extra element to make it invalid

    // Bystander uses permit to approve bystander to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    // behalf
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'AT: invalid signature')]
fn test_permit_incorrect_sig_length_should_panic2() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details, spender: setup.bystander, sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    // Mess with sig length
    let (r, _): (felt252, felt252) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r]; // Add an extra element to make it invalid

    // Bystander uses permit to approve bystander to spend `DEFAULT_AMOUNT` of `token0` on `from`s
    // behalf
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);
}

#[test]
#[should_panic(expected: 'AT: invalid signature')]
fn test_permit_incorrect_owner_should_panic() {
    let setup = setup();
    let default_expiration = get_block_timestamp() + 5;

    let details = PermitDetails {
        token: setup.token0.contract_address,
        amount: DEFAULT_AMOUNT,
        expiration: default_expiration,
        nonce: DEFAULT_NONCE,
    };
    let permit = PermitSingle {
        details,
        spender: setup.to.account.contract_address,
        sig_deadline: (get_block_timestamp() + 100).into(),
    };

    // Hash the permit message
    let message_hash = permit.get_message_hash(setup.from.account.contract_address);
    // Mess with sig length
    let (r, s): (felt252, felt252) = setup.from.key_pair.sign(message_hash).unwrap();
    let signature = array![r, s, 0]; // Add an extra element to make it invalid

    // Bystander tries to use the permit signed for `to`
    start_cheat_caller_address(setup.permit2.contract_address, setup.bystander);
    setup.permit2.permit(setup.from.account.contract_address, permit, signature);
    stop_cheat_caller_address(setup.permit2.contract_address);
}
// #[test]
// #[ignore]
// fn test_should_set_allowance_compact_sig() {}
//
// #[test]
// #[ignore]
// fn test_should_set_allowance_dirty_write() {}


