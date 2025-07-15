#[starknet::interface]
pub trait IMockNonPermitToken<TState> {
    fn DOMAIN_SEPARATOR(self: @TState) -> felt252;
    fn mint(ref self: TState, recipient: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MockNonPermitToken {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use super::IMockNonPermitToken;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.erc20.initializer(name, symbol);
    }

    pub impl ImutableConfig of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 18;
    }

    #[abi(embed_v0)]
    impl MockNonPermitTokenImpl of IMockNonPermitToken<ContractState> {
        fn DOMAIN_SEPARATOR(self: @ContractState) -> felt252 {
            0
        }
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }
    }
}

