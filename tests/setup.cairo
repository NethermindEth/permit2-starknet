use core::num::traits::Bounded;
use openzeppelin_token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20PermitDispatcher,
};
use permit2::interfaces::allowance_transfer::IAllowanceTransferDispatcher;
use permit2::interfaces::signature_transfer::ISignatureTransferDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address_global,
    stop_cheat_caller_address_global,
};
use starknet::ContractAddress;
use crate::common::{
    Account, E18, create_erc20_token, create_larger_ds_token, create_mock_non_permit_token,
    create_mock_permit2_lib, create_mock_permit_token, create_small_ds_token, generate_account,
};
use crate::mocks::interfaces::{
    IMintableDispatcher, IMintableDispatcherTrait, IMockNonPermitTokenDispatcher,
    IPermitWithDSDispatcher,
};
use crate::mocks::mock_permit2_lib::IMockPermit2LibDispatcher;


#[derive(Drop, Copy)]
pub struct SetupAT {
    pub from: Account,
    pub to: Account,
    pub owner: ContractAddress,
    pub bystander: ContractAddress,
    pub token0: IERC20Dispatcher,
    pub token1: IERC20Dispatcher,
    pub permit2: IAllowanceTransferDispatcher,
}

#[derive(Drop, Copy)]
pub struct SetupST {
    pub from: Account,
    pub to: Account,
    pub owner: ContractAddress,
    pub bystander: ContractAddress,
    pub token0: IERC20Dispatcher,
    pub token1: IERC20Dispatcher,
    pub permit2: ISignatureTransferDispatcher,
}

#[derive(Drop, Copy)]
pub struct SetupPermit2Lib {
    pub this: ContractAddress,
    pub pk_owner: Account,
    pub to: Account,
    pub bystander: ContractAddress,
    pub permit2: ISignatureTransferDispatcher,
    pub permit2_lib: IMockPermit2LibDispatcher,
    pub token: IERC20PermitDispatcher,
    pub non_permit_token: IMockNonPermitTokenDispatcher,
    pub small_ds_token: IPermitWithDSDispatcher,
    pub larger_ds_token: IPermitWithDSDispatcher,
    pub fallback_token: IERC20PermitDispatcher,
}

pub fn deploy_mock_permit2() -> ContractAddress {
    let mock_permit2_contract = declare("MockPermit2").unwrap().contract_class();
    let (mock_permit2_address, _) = mock_permit2_contract
        .deploy(@array![])
        .expect('mock permit2 deployment failed');

    mock_permit2_address
}

pub fn deploy_permit2() -> ContractAddress {
    let permit2_contract = declare("Permit2").unwrap().contract_class();
    let (permit2_address, _) = permit2_contract
        .deploy(@array![])
        .expect('permit2 deployment failed');

    permit2_address
}

pub fn setup_permit2_lib() -> SetupPermit2Lib {
    // Deploy permit2
    let permit2_address = deploy_permit2();
    let permit2_ = ISignatureTransferDispatcher { contract_address: permit2_address };

    // Create accounts
    let (pk_owner, to, _, bystander) = create_accounts();
    let this = starknet::get_contract_address();

    // Deploy tokens
    let token = create_mock_permit_token("Mock Token", "MOCK");
    let non_permit_token = create_mock_non_permit_token("Mock Non-Permit Token", "MOCK");
    let small_ds_token = create_small_ds_token("Small DS Token", "SDS");
    let larger_ds_token = create_larger_ds_token("Larger DS Token", "LDS");
    let permit2_lib = create_mock_permit2_lib(permit2_address);
    let fallback_token = create_mock_permit_token("Fallback Token", "MOCK");

    mint(token.contract_address, this, 1000 * E18);
    approve_max(token.contract_address, this, this);
    approve_max(token.contract_address, this, permit2_address);

    mint(small_ds_token.contract_address, this, 1000 * E18);
    approve_max(small_ds_token.contract_address, this, this);
    approve_max(small_ds_token.contract_address, this, permit2_address);

    mint(token.contract_address, pk_owner.account.contract_address, 1000 * E18);
    approve_max(token.contract_address, pk_owner.account.contract_address, permit2_address);

    mint(small_ds_token.contract_address, pk_owner.account.contract_address, 1000 * E18);
    approve_max(
        small_ds_token.contract_address, pk_owner.account.contract_address, permit2_address,
    );

    mint(fallback_token.contract_address, this, 1000 * E18);
    approve_max(fallback_token.contract_address, this, this);
    approve_max(fallback_token.contract_address, this, permit2_address);

    mint(fallback_token.contract_address, pk_owner.account.contract_address, 1000 * E18);
    approve_max(
        fallback_token.contract_address, pk_owner.account.contract_address, permit2_address,
    );

    mint(non_permit_token.contract_address, this, 1000 * E18);
    approve_max(non_permit_token.contract_address, this, this);
    approve_max(non_permit_token.contract_address, this, permit2_address);

    mint(non_permit_token.contract_address, pk_owner.account.contract_address, 1000 * E18);
    approve_max(
        non_permit_token.contract_address, pk_owner.account.contract_address, permit2_address,
    );

    SetupPermit2Lib {
        pk_owner,
        this,
        to,
        bystander,
        permit2: permit2_,
        permit2_lib,
        token,
        non_permit_token,
        small_ds_token,
        larger_ds_token,
        fallback_token,
    }
}


pub fn deploy_erc20_tokens(
    recipient: ContractAddress, owner: ContractAddress,
) -> (IERC20Dispatcher, IERC20Dispatcher) {
    let token0 = create_erc20_token("Token 0", "TKN0");
    let token1 = create_erc20_token("Token 1", "TKN1");

    (token0, token1)
}

pub fn create_accounts() -> (Account, Account, ContractAddress, ContractAddress) {
    let from = generate_account();
    let to = generate_account();
    let owner = 'owner'.try_into().unwrap();
    let bystander = 'bystander'.try_into().unwrap();

    (from, to, owner, bystander)
}

pub fn mint(token: ContractAddress, recipient: ContractAddress, amount: u256) {
    IMintableDispatcher { contract_address: token }.mint(recipient, amount);
}

pub fn topup_accounts(token: ContractAddress, recipients: Array<ContractAddress>, amount: u256) {
    for recipient in recipients {
        IMintableDispatcher { contract_address: token }.mint(recipient, amount);
    }
}

pub fn approve_max(token: ContractAddress, owner: ContractAddress, spender: ContractAddress) {
    start_cheat_caller_address_global(owner);
    IERC20Dispatcher { contract_address: token }.approve(spender, Bounded::MAX);
    stop_cheat_caller_address_global();
}

pub fn approve_maxxes(
    tokens: Array<ContractAddress>, owners: Array<ContractAddress>, spender: ContractAddress,
) {
    for token in tokens {
        for owner in owners.clone() {
            approve_max(token, owner, spender);
        }
    }
}

pub fn setupST() -> SetupST {
    // Deploy permit2
    let permit2_address = deploy_permit2();
    let permit2 = ISignatureTransferDispatcher { contract_address: permit2_address };

    let (from, to, owner, bystander) = create_accounts();
    let (token0, token1) = deploy_erc20_tokens(bystander, owner);

    mint(token0.contract_address, from.account.contract_address, 100 * E18);
    mint(token1.contract_address, from.account.contract_address, 100 * E18);

    approve_max(token0.contract_address, from.account.contract_address, permit2_address);
    approve_max(token1.contract_address, from.account.contract_address, permit2_address);

    SetupST { from, to, owner, bystander, token0, token1, permit2 }
}

pub fn setupAT() -> SetupAT {
    // Deploy permit2
    let permit2_address = deploy_permit2();
    let permit2 = IAllowanceTransferDispatcher { contract_address: permit2_address };

    let (from, to, owner, bystander) = create_accounts();
    let (token0, token1) = deploy_erc20_tokens(bystander, owner);

    topup_accounts(
        token0.contract_address,
        array![from.account.contract_address, to.account.contract_address, bystander],
        1000 * E18,
    );
    topup_accounts(
        token1.contract_address,
        array![from.account.contract_address, to.account.contract_address, bystander],
        1000 * E18,
    );

    approve_maxxes(
        array![token0.contract_address, token1.contract_address],
        array![from.account.contract_address, to.account.contract_address],
        permit2_address,
    );

    SetupAT { from, to, owner, bystander, token0, token1, permit2 }
}
