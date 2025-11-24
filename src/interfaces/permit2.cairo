#[starknet::interface]
pub trait IDomainSeparator<TState> {
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
}

