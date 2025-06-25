#[starknet::interface]
pub trait IMintable<TContractState> {
    fn mint(ref self: TContractState, recipient: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MockRC20Permit {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20PermitImpl = ERC20Component::ERC20PermitImpl<ContractState>;

    #[abi(embed_v0)]
    impl SNIP12MetadataExternal =
        ERC20Component::SNIP12MetadataExternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pub nonces: NoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
    }

    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'Mock token'
        }
        fn version() -> felt252 {
            'v1'
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }

    #[abi(embed_v0)]
    impl MintableImpl of super::IMintable<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.mint(recipient, amount);
        }
    }
}
