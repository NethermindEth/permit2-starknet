use starknet::ContractAddress;

#[starknet::interface]
pub trait ISRC6Partial<TState> {
    /// Reads ///

    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
}
