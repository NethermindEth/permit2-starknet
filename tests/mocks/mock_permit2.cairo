use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockPermit2<TState> {
    fn mock_update_amount_and_expiration(
        ref self: TState,
        from: ContractAddress,
        token: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
    );

    fn mock_update_all(
        ref self: TState,
        from: ContractAddress,
        token: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
        nonce: u64,
    );

    fn use_unordered_nonce(ref self: TState, from: ContractAddress, nonce: felt252);
}

#[starknet::contract]
mod MockPermit2 {
    use permit2::components::unordered_nonces::UnorderedNoncesComponent;
    use permit2::libraries::allowance::{Allowance, AllowanceImpl, AllowanceTrait};
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry};


    component!(path: UnorderedNoncesComponent, storage: nonces, event: UnorderedNoncesEvent);

    #[abi(embed_v0)]
    impl UnorderedNoncesImpl =
        UnorderedNoncesComponent::UnorderedNoncesImpl<ContractState>;
    impl UnorderedNoncesInternalImpl = UnorderedNoncesComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        allowance: Map<(ContractAddress, ContractAddress, ContractAddress), Allowance>,
        #[substorage(v0)]
        nonces: UnorderedNoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UnorderedNoncesEvent: UnorderedNoncesComponent::Event,
    }

    #[abi(embed_v0)]
    impl MockPermit2Impl of super::IMockPermit2<ContractState> {
        fn mock_update_amount_and_expiration(
            ref self: ContractState,
            from: ContractAddress,
            token: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            expiration: u64,
        ) {
            let mut s_allowance = self.allowance.entry((from, token, spender));
            s_allowance.update_amount_and_expiration(amount, expiration);
        }

        fn mock_update_all(
            ref self: ContractState,
            from: ContractAddress,
            token: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            expiration: u64,
            nonce: u64,
        ) {
            let mut s_allowance = self.allowance.entry((from, token, spender));

            s_allowance.update_all(amount, expiration, nonce);
        }

        fn use_unordered_nonce(ref self: ContractState, from: ContractAddress, nonce: felt252) {
            self.nonces._use_unordered_nonce(from, nonce);
        }
    }
}
