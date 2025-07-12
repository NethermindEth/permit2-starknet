#[starknet::component]
pub mod SignatureTransferComponent {
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use permit2::components::unordered_nonces::UnorderedNoncesComponent;
    use permit2::components::unordered_nonces::UnorderedNoncesComponent::{
        InternalTrait as NoncesInternalTrait, UnorderedNoncesImpl,
    };
    use permit2::interfaces::signature_transfer::{
        ISignatureTransfer, PermitBatchTransferFrom, PermitTransferFrom, SignatureTransferDetails,
        errors,
    };
    use permit2::libraries::permit_hash::{
        OffchainMessageHashWitnessTrait, PermitBatchStructHash, PermitBatchTransferFromStructHash,
        PermitBatchTransferFromStructHashWitness, PermitSingleStructHash,
        PermitTransferFromStructHash, PermitTransferFromStructHashWitness,
        TokenPermissionsStructHash,
    };
    use starknet::ContractAddress;

    /// STORAGE ///

    #[storage]
    pub struct Storage {}

    /// PUBLIC ///

    #[embeddable_as(SignatureTransferImpl)]
    impl SignatureTransfer<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Nonces: UnorderedNoncesComponent::HasComponent<TContractState>,
        impl Metadata: SNIP12Metadata,
    > of ISignatureTransfer<ComponentState<TContractState>> {
        /// Writes ///

        fn permit_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            signature: Array<felt252>,
        ) {
            self
                ._permit_transfer_from(
                    permit, transfer_details, owner, permit.get_message_hash(owner), signature,
                );
        }

        fn permit_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitBatchTransferFrom,
            transfer_details: Span<SignatureTransferDetails>,
            owner: ContractAddress,
            signature: Array<felt252>,
        ) {
            self
                ._permit_batch_transfer_from(
                    permit, transfer_details, owner, permit.get_message_hash(owner), signature,
                );
        }


        fn permit_witness_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            witness: felt252,
            witness_type_string: ByteArray,
            signature: Array<felt252>,
        ) {
            self
                ._permit_transfer_from(
                    permit,
                    transfer_details,
                    owner,
                    permit.get_message_hash_with_witness(owner, witness, witness_type_string),
                    signature,
                );
        }

        fn permit_witness_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitBatchTransferFrom,
            transfer_details: Span<SignatureTransferDetails>,
            owner: ContractAddress,
            witness: felt252,
            witness_type_string: ByteArray,
            signature: Array<felt252>,
        ) {
            self
                ._permit_batch_transfer_from(
                    permit,
                    transfer_details,
                    owner,
                    permit.get_message_hash_with_witness(owner, witness, witness_type_string),
                    signature,
                );
        }
    }

    /// INTERNAL ///

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Nonces: UnorderedNoncesComponent::HasComponent<TContractState>,
        impl Metadata: SNIP12Metadata,
    > of InternalTrait<TContractState> {
        fn _permit_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            data_hash: felt252,
            signature: Array<felt252>,
        ) {
            // Validate signature deadline
            assert(
                starknet::get_block_timestamp() <= permit.deadline.try_into().unwrap(),
                errors::SignatureExpired,
            );

            // Validate transfer amount <= permitted amount
            let requested_amount = transfer_details.requested_amount;
            assert(requested_amount <= permit.permitted.amount, errors::InvalidAmount);

            // Use nonce
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component._use_unordered_nonce(owner, permit.nonce);

            // Validate signature
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            let is_valid = src6_dispatcher.is_valid_signature(data_hash, signature);
            assert(is_valid == starknet::VALIDATED, errors::InvalidSignature);

            // Transfer tokens
            /// TODO: Assert return value
            // @dev: Needed ? Dispatcher should fail if transfer fails ?
            IERC20Dispatcher { contract_address: permit.permitted.token }
                .transfer_from(owner, transfer_details.to, requested_amount);
        }

        fn _permit_batch_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitBatchTransferFrom,
            transfer_details: Span<SignatureTransferDetails>,
            owner: ContractAddress,
            data_hash: felt252,
            signature: Array<felt252>,
        ) {
            // Validate signature deadline
            assert(
                starknet::get_block_timestamp() <= permit.deadline.try_into().unwrap(),
                errors::SignatureExpired,
            );

            // Validate permit & transfer detail lengths
            assert(permit.permitted.len() == transfer_details.len(), errors::LengthMismatch);

            // Use nonce
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component._use_unordered_nonce(owner, permit.nonce);

            // Validate signature
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            let is_valid = src6_dispatcher.is_valid_signature(data_hash, signature);
            assert(is_valid == starknet::VALIDATED, errors::InvalidSignature);

            // Iterate over each permitted token and transfer detail
            for (permitted, transfer_detail) in permit.permitted.into_iter().zip(transfer_details) {
                // Validate requested amount <= permitted amount
                let requested_amount = *transfer_detail.requested_amount;
                assert(requested_amount <= *permitted.amount, 'InvalidAmount');

                // Transfer tokens
                if requested_amount > 0 {
                    /// TODO: Assert return value
                    // @dev: Needed ? Dispatcher should fail if transfer fails ?
                    IERC20Dispatcher { contract_address: *permitted.token }
                        .transfer_from(owner, *transfer_detail.to, requested_amount);
                }
            }
        }
    }
}
