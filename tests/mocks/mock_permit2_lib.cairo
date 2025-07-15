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
    fn permit2(
        ref self: TState,
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Array<felt252>,
    );

    fn simple_permit2(
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
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};


    #[storage]
    struct Storage {
        permit2_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, permit2_address: ContractAddress) {
        self.permit2_address.write(permit2_address);
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
            Permit2Lib::transfer_from2(token, from, to, amount, self.permit2_address.read());
        }

        fn permit2(
            ref self: ContractState,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u64,
            signature: Array<felt252>,
        ) {
            Permit2Lib::permit2(
                token, owner, spender, amount, deadline, signature, self.permit2_address.read(),
            );
        }

        fn simple_permit2(
            ref self: ContractState,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u64,
            signature: Array<felt252>,
        ) {
            Permit2Lib::simple_permit2(
                token,
                owner,
                spender,
                amount,
                deadline.into(),
                signature,
                self.permit2_address.read(),
            );
        }
    }
}
