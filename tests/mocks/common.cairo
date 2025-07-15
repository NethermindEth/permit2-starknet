#[starknet::interface]
pub trait IMintable<TContractState> {
    fn mint(ref self: TContractState, recipient: starknet::ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IPermitWithDS<TState> {
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
    fn mint(ref self: TState, recipient: starknet::ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IMockNonPermitToken<TState> {
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
    fn mint(ref self: TState, recipient: starknet::ContractAddress, amount: u256);
}

