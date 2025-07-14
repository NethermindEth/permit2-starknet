#[starknet::contract]
pub mod Permit2 {
    use openzeppelin_utils::cryptography::snip12::{
        SNIP12Metadata, StarknetDomain, StructHashStarknetDomainImpl,
    };
    use permit2::components::allowance_transfer::AllowanceTransferComponent;
    use permit2::components::signature_transfer::SignatureTransferComponent;
    use permit2::components::unordered_nonces::UnorderedNoncesComponent;
    use permit2::interfaces::permit2::IPermit2;
    use starknet::get_tx_info;


    component!(
        path: AllowanceTransferComponent, storage: allowed_transfer, event: AllowedTransferEvent,
    );
    component!(path: UnorderedNoncesComponent, storage: nonces, event: UnorderedNoncesEvent);
    component!(
        path: SignatureTransferComponent,
        storage: signature_transfer,
        event: SignatureTransferEvent,
    );

    #[abi(embed_v0)]
    impl AllowedTransferImpl =
        AllowanceTransferComponent::AllowanceTransferImpl<ContractState>;

    #[abi(embed_v0)]
    impl SignatureTransferImpl =
        SignatureTransferComponent::SignatureTransferImpl<ContractState>;

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

    #[abi(embed_v0)]
    pub impl Permit2 of IPermit2<ContractState> {
        fn DOMAIN_SEPARATOR(self: @ContractState) -> felt252 {
            let domain = StarknetDomain {
                name: SNIP12MetadataImpl::name(),
                version: SNIP12MetadataImpl::version(),
                chain_id: get_tx_info().unbox().chain_id,
                revision: 1,
            };

            domain.hash_struct()
        }
    }
}

