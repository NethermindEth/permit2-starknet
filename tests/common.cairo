use openzeppelin_account::interface::AccountABIDispatcher;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20PermitDispatcher};
use snforge_std::signature::stark_curve::{
    StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
};
use snforge_std::signature::{KeyPair, KeyPairTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::mocks::interfaces::{IMockNonPermitTokenDispatcher, IPermitWithDSDispatcher};
use crate::mocks::mock_permit2_lib::IMockPermit2LibDispatcher;

pub const E18: u256 = 1_000_000_000_000_000_000;
pub const INITIAL_SUPPLY: u256 = 1000 * E18;

#[derive(Drop, Copy)]
pub struct Account {
    pub account: AccountABIDispatcher,
    pub key_pair: KeyPair<felt252, felt252>,
}

pub fn create_erc20_token(name: ByteArray, symbol: ByteArray) -> IERC20Dispatcher {
    let mock_erc20_contract = declare("MockERC20").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_erc20_contract.deploy(@ctor_calldata).unwrap();
    IERC20Dispatcher { contract_address: erc20_address }
}

pub fn create_mock_non_permit_token(
    name: ByteArray, symbol: ByteArray,
) -> IMockNonPermitTokenDispatcher {
    let mock_non_permit_contract = declare("MockNonPermitToken").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_non_permit_contract.deploy(@ctor_calldata).unwrap();
    IMockNonPermitTokenDispatcher { contract_address: erc20_address }
}

pub fn create_mock_permit_token(name: ByteArray, symbol: ByteArray) -> IERC20PermitDispatcher {
    let mock_non_permit_contract = declare("MockERC20Permit").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_non_permit_contract.deploy(@ctor_calldata).unwrap();
    IERC20PermitDispatcher { contract_address: erc20_address }
}

pub fn create_mock_permit2_lib(permit2_address: ContractAddress) -> IMockPermit2LibDispatcher {
    let mock_permit2_lib_contract = declare("MockPermit2Lib").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    permit2_address.serialize(ref ctor_calldata);

    let (permit2_lib_address, _) = mock_permit2_lib_contract.deploy(@ctor_calldata).unwrap();
    IMockPermit2LibDispatcher { contract_address: permit2_lib_address }
}

//pub fn create_mock_fallback_token() {
//
//
//}

pub fn create_small_ds_token(name: ByteArray, symbol: ByteArray) -> IPermitWithDSDispatcher {
    let mock_non_permit_contract = declare("MockPermitWithSmallDS").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_non_permit_contract.deploy(@ctor_calldata).unwrap();
    IPermitWithDSDispatcher { contract_address: erc20_address }
}

pub fn create_larger_ds_token(name: ByteArray, symbol: ByteArray) -> IPermitWithDSDispatcher {
    let mock_non_permit_contract = declare("MockPermitWithLargerDS").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_non_permit_contract.deploy(@ctor_calldata).unwrap();
    IPermitWithDSDispatcher { contract_address: erc20_address }
}

pub fn generate_account() -> Account {
    let mock_account_contract = declare("MockAccount").unwrap().contract_class();
    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let (account_address, _) = mock_account_contract.deploy(@array![key_pair.public_key]).unwrap();
    let account = AccountABIDispatcher { contract_address: account_address };
    Account { account, key_pair }
}

