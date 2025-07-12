use core::num::traits::Bounded;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use permit2::interfaces::allowance_transfer::IAllowanceTransferDispatcher;
use permit2::interfaces::signature_transfer::ISignatureTransferDispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address_global,
    stop_cheat_caller_address_global,
};
use starknet::ContractAddress;
use crate::common::{Account, E18, INITIAL_SUPPLY, create_erc20_token, generate_account};


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
    pub from: Account,
    pub to: Account,
    pub owner: ContractAddress,
    pub bystander: ContractAddress,
    pub erc20permit: IERC20Dispatcher,
    pub erc20: IERC20Dispatcher,
    pub permit2: IAllowanceTransferDispatcher,
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
    let permit2 = ISignatureTransferDispatcher { contract_address: permit2_address };

    // Create accounts
    let (from, to, owner, bystander) = create_accounts();

    // Deploy 2 erc20 tokens
    let (token0, token1) = deploy_erc20_tokens(bystander, owner);

    // The bystander tops up the from account with tokens
    topup_account(token0, bystander, from.account.contract_address, 100 * E18);
    topup_account(token1, bystander, from.account.contract_address, 100 * E18);

    // The from address approves permit2 to transfer MAX tokens
    approve_max(token0, from.account.contract_address, permit2_address);
    approve_max(token1, from.account.contract_address, permit2_address);

    SetupST { from, to, owner, bystander, token0, token1, permit2 }
}


pub fn deploy_erc20_tokens(
    recipient: ContractAddress, owner: ContractAddress,
) -> (IERC20Dispatcher, IERC20Dispatcher) {
    let token0 = create_erc20_token("Token 0", "TKN0", INITIAL_SUPPLY, recipient, owner);
    let token1 = create_erc20_token("Token 1", "TKN1", INITIAL_SUPPLY, recipient, owner);

    (token0, token1)
}

pub fn create_accounts() -> (Account, Account, ContractAddress, ContractAddress) {
    let from = generate_account();
    let to = generate_account();
    let owner = 'owner'.try_into().unwrap();
    let bystander = 'bystander'.try_into().unwrap();

    (from, to, owner, bystander)
}

pub fn topup_account(
    token: IERC20Dispatcher, sender: ContractAddress, recipient: ContractAddress, amount: u256,
) {
    start_cheat_caller_address_global(sender);
    token.transfer(recipient, amount);
    stop_cheat_caller_address_global();
}

pub fn approve_max(token: IERC20Dispatcher, owner: ContractAddress, spender: ContractAddress) {
    start_cheat_caller_address_global(owner);
    token.approve(spender, Bounded::MAX);
    stop_cheat_caller_address_global();
}

pub fn setupST() -> SetupST {
    // Deploy permit2
    let permit2_address = deploy_permit2();
    let permit2 = ISignatureTransferDispatcher { contract_address: permit2_address };

    // Create accounts
    let (from, to, owner, bystander) = create_accounts();

    // Deploy 2 erc20 tokens
    let (token0, token1) = deploy_erc20_tokens(bystander, owner);

    // The bystander tops up the from account with tokens
    topup_account(token0, bystander, from.account.contract_address, 100 * E18);
    topup_account(token1, bystander, from.account.contract_address, 100 * E18);

    // The from address approves permit2 to transfer MAX tokens
    approve_max(token0, from.account.contract_address, permit2_address);
    approve_max(token1, from.account.contract_address, permit2_address);

    SetupST { from, to, owner, bystander, token0, token1, permit2 }
}

pub fn setupAT() -> SetupAT {
    // Deploy permit2
    let permit2_address = deploy_permit2();
    let permit2 = IAllowanceTransferDispatcher { contract_address: permit2_address };

    // Create accounts
    let (from, to, owner, bystander) = create_accounts();

    // Deploy 2 erc20 tokens
    let (token0, token1) = deploy_erc20_tokens(bystander, owner);

    // The bystander tops up the from & to account with tokens
    topup_account(token0, bystander, from.account.contract_address, 100 * E18);
    topup_account(token1, bystander, from.account.contract_address, 100 * E18);
    topup_account(token0, bystander, to.account.contract_address, 100 * E18);
    topup_account(token1, bystander, to.account.contract_address, 100 * E18);

    // The from address approves permit2 to transfer MAX tokens
    approve_max(token0, from.account.contract_address, permit2_address);
    approve_max(token1, from.account.contract_address, permit2_address);
    // The to address approves permit2 to transfer MAX tokens
    approve_max(token0, to.account.contract_address, permit2_address);
    approve_max(token1, to.account.contract_address, permit2_address);

    SetupAT { from, to, owner, bystander, token0, token1, permit2 }
}
