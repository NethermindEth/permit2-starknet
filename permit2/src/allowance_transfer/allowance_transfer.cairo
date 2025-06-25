#[starknet::component]
pub mod AllowanceTransferComponent {
    use permit2::allowance_transfer::interface::{
        AllowanceTransferDetails, IAllowanceTransfer, PermitBatch, PermitSingle, TokenSpenderPair,
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        pub nonce_bitmap: Map<(ContractAddress, u256), u256>,
    }

    /// EVENTS ///

    #[event]
    #[derive(starknet::Event, Drop)]
    pub enum Event {
        NonceInvalidation: NonceInvalidation,
        Approval: Approval,
        PermitSingleEvent: PermitSingleEvent,
        LockdownEvent: LockdownEvent,
    }

    /// @notice Emits an event when the owner successfully invalidates an ordered nonce.
    #[derive(starknet::Event, Drop)]
    pub struct NonceInvalidation {
        #[key]
        owner: ContractAddress,
        #[key]
        token: ContractAddress,
        #[key]
        spender: ContractAddress,
        new_nonce: u64,
        old_nonce: u64,
    }


    /// @notice Emits an event when the owner successfully sets permissions on a token for the
    /// spender.
    #[derive(starknet::Event, Drop)]
    pub struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        token: ContractAddress,
        #[key]
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
    }

    /// @notice Emits an event when the owner successfully sets permissions using a permit signature
    /// on a token for the spender.
    #[derive(starknet::Event, Drop)]
    pub struct PermitSingleEvent {
        #[key]
        owner: ContractAddress,
        #[key]
        token: ContractAddress,
        #[key]
        spender: ContractAddress,
        amount: u256,
        expiration: u64,
        nonce: u64,
    }

    /// @notice Emits an event when the owner sets the allowance back to 0 with the lockdown
    /// function.
    #[derive(starknet::Event, Drop)]
    pub struct LockdownEvent {
        #[key]
        owner: ContractAddress,
        token: ContractAddress,
        spender: ContractAddress,
    }


    #[embeddable_as(AllowanceTransferImpl)]
    impl AllowanceTransfer<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IAllowanceTransfer<ComponentState<TContractState>> {
        /// Reads ///

        fn allowance(
            self: @ComponentState<TContractState>,
            user: ContractAddress,
            token: ContractAddress,
            spender: ContractAddress,
        ) -> (u256, u64, u64) {
            (0, 0, 0)
        }

        /// Writes ///
        fn approve(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            expiration: u64,
        ) {}

        fn permit(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            permitSingle: PermitSingle,
            signature: ByteArray,
        ) {}

        fn permit_batch(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            permitSingle: PermitBatch,
            signature: ByteArray,
        ) {}

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            token: ContractAddress,
        ) {}

        fn transfer_from_batch(
            ref self: ComponentState<TContractState>,
            transferDetails: Span<AllowanceTransferDetails>,
        ) {}

        fn lockdown(ref self: ComponentState<TContractState>, approvals: Span<TokenSpenderPair>) {}

        fn invalidate_nonces(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            spender: ContractAddress,
            new_nonce: u64,
        ) {}
    }
}
