#[starknet::component]
mod MockPermit2Lib {
    use openzeppelin_account::AccountComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use permit2::libraries::permit2_lib::Permit2Lib;

    component!(path: Permit2Lib, storage: account, event: Permit2LibEvent);

    impl Permit2LibImpl = Permit2Lib::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        permit2: ContractAddress,
        #[substorage(v0)]
        permit2_lib: Permit2Lib::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        Permit2LibEvent: Permit2LibComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, permit2: ContractAddress) {
        self.permit2.write(permit2);
    }

    fn transfer_from(
        ref self: ContractState,
        token: ContractAddres,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
    ) {
        self.permit2_lib._transfer_from2(token, from, to, amount);
    }

    fn permit(
        ref self: ContractState,
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u256,
        signature: Span<felt252>,
    ) {
        self.permit2_lib._permit2(token, owner, spender, amount, deadline, signature);
    }
}
