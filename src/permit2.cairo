#[starknet::contract]
pub mod Permit2 {
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use crate::allowance_transfer::allowance_transfer::AllowanceTransferComponent;
    use crate::libraries::unordered_nonces::UnorderedNoncesComponent;
    use crate::signature_transfer::signature_transfer::SignatureTransferComponent;

    component!(
        path: AllowanceTransferComponent, storage: allowed_transfer, event: AllowedTransferEvent,
    );

    #[abi(embed_v0)]
    impl AllowedTransferImpl =
        AllowanceTransferComponent::AllowanceTransferImpl<ContractState>;

    component!(
        path: SignatureTransferComponent,
        storage: signature_transfer,
        event: SignatureTransferEvent,
    );

    #[abi(embed_v0)]
    impl SignatureTransferImpl =
        SignatureTransferComponent::SignatureTransferImpl<ContractState>;

    component!(path: UnorderedNoncesComponent, storage: nonces, event: UnorderedNoncesEvent);

    #[abi(embed_v0)]
    impl UnorderedNoncesImpl =
        UnorderedNoncesComponent::UnorderedNoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        allowed_transfer: AllowanceTransferComponent::Storage,
        #[substorage(v0)]
        signature_transfer: SignatureTransferComponent::Storage,
        #[substorage(v0)]
        nonces: UnorderedNoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AllowedTransferEvent: AllowanceTransferComponent::Event,
        #[flat]
        SignatureTransferEvent: SignatureTransferComponent::Event,
        #[flat]
        UnorderedNoncesEvent: UnorderedNoncesComponent::Event,
    }

    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        /// Returns the name of the SNIP-12 metadata.
        fn name() -> felt252 {
            'Permit2'
        }

        /// Returns the version of the SNIP-12 metadata.
        fn version() -> felt252 {
            'v1'
        }
    }
}
