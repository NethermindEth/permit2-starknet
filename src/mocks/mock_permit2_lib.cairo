use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockPermit2Lib<TState> {
    fn transfer_from2(
        ref self: TState,
        token: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
    );

    /// @dev `_` added to avoid conflict with the module named `permit2`
    fn permit2_(
        ref self: TState,
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Array<felt252>,
    );
}

#[starknet::contract]
mod MockPermit2Lib {
    use permit2::libraries::permit2_lib::Permit2Lib;
    use starknet::ContractAddress;

    component!(path: Permit2Lib, storage: permit2_lib, event: Permit2LibEvent);

    impl Permit2LibImpl = Permit2Lib::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        permit2_lib: Permit2Lib::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        Permit2LibEvent: Permit2Lib::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, permit2_address: ContractAddress) {
        self.permit2_lib._initialize(permit2_address);
    }

    #[abi(embed_v0)]
    impl MockPermit2LibImpl of super::IMockPermit2Lib<ContractState> {
        fn transfer_from2(
            ref self: ContractState,
            token: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) {
            self.permit2_lib._transfer_from2(token, from, to, amount);
        }

        fn permit2_(
            ref self: ContractState,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u64,
            signature: Array<felt252>,
        ) {
            self.permit2_lib._permit2(token, owner, spender, amount, deadline, signature);
        }
    }
}
