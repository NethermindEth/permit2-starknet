use openzeppelin_account::interface::AccountABIDispatcher;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::signature::stark_curve::{
    StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
};
use snforge_std::signature::{KeyPair, KeyPairTrait, SignerTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

pub const E18: u256 = 1_000_000_000_000_000_000;
pub const INITIAL_SUPPLY: u256 = 1000 * E18;

#[derive(Drop, Copy)]
pub struct Account {
    pub account: AccountABIDispatcher,
    pub key_pair: KeyPair<felt252, felt252>,
}

pub fn create_erc20_token(
    name: ByteArray,
    symbol: ByteArray,
    initial_supply: u256,
    recepient: ContractAddress,
    owner: ContractAddress,
) -> IERC20Dispatcher {
    let mock_erc20_contract = declare("MockERC20").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    name.serialize(ref ctor_calldata);
    symbol.serialize(ref ctor_calldata);
    initial_supply.serialize(ref ctor_calldata);
    recepient.serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);

    let (erc20_address, _) = mock_erc20_contract.deploy(@ctor_calldata).unwrap();
    IERC20Dispatcher { contract_address: erc20_address }
}

pub fn generate_account() -> Account {
    let mock_account_contract = declare("MockAccount").unwrap().contract_class();
    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let (account_address, _) = mock_account_contract.deploy(@array![key_pair.public_key]).unwrap();
    let account = AccountABIDispatcher { contract_address: account_address };
    Account { account, key_pair }
}
