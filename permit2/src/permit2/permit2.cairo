#[starknet::contract]
pub mod Permit2 {
    use permit2::allowance_transfer::allowance_transfer::AllowanceTransferComponent;
    use permit2::permit2::interface::IPermit2;
    use permit2::signature_transfer::signature_transfer::SignatureTransferComponent;


    component!(
        path: AllowanceTransferComponent,
        storage: allowance_transfer,
        event: AllowanceTransferEvent,
    );
    component!(
        path: SignatureTransferComponent,
        storage: signature_transfer,
        event: SignatureTransferEvent,
    );

    #[abi(embed_v0)]
    impl AllowanceTransferImpl =
        AllowanceTransferComponent::AllowanceTransferImpl<ContractState>;
    #[abi(embed_v0)]
    impl SignatureTransferImpl =
        SignatureTransferComponent::SignatureTransferImpl<ContractState>;


    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub allowance_transfer: AllowanceTransferComponent::Storage,
        #[substorage(v0)]
        #[allow(starknet::colliding_storage_paths)]
        pub signature_transfer: SignatureTransferComponent::Storage,
    }

    #[event]
    #[derive(starknet::Event, Drop)]
    enum Event {
        #[flat]
        AllowanceTransferEvent: AllowanceTransferComponent::Event,
        #[flat]
        SignatureTransferEvent: SignatureTransferComponent::Event,
    }

    #[abi(embed_v0)]
    impl Permit2Impl of IPermit2<ContractState> {}
}
