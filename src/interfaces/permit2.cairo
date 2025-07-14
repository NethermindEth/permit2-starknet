#[starknet::interface]
pub trait IPermit2<TState> {
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
}

