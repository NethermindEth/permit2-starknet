#[starknet::component]
pub mod SignatureTransferComponent {
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use starknet::ContractAddress;
    use crate::libraries::unordered_nonces::UnorderedNoncesComponent;
    use crate::libraries::unordered_nonces::UnorderedNoncesComponent::InternalTrait as NoncesInternalTrait;
    use crate::signature_transfer::interface::{
        ISignatureTransfer, PermitBatchTransferFrom, PermitTransferFrom, SignatureTransferDetails,
    };
    use crate::signature_transfer::snip12_utils::{
        PermitBatchTransferFromStructHash, PermitTransferFromStructHash, SNIP12HashWitnessTrait,
        TokenPermissionsStructHash,
    };

    #[storage]
    pub struct Storage {}

    #[embeddable_as(SignatureTransferImpl)]
    pub impl SignatureTransfer<
        TContractState,
        +HasComponent<TContractState>,
        impl Nonces: UnorderedNoncesComponent::HasComponent<TContractState>,
        impl Metadata: SNIP12Metadata,
        +Drop<TContractState>,
    > of ISignatureTransfer<ComponentState<TContractState>> {
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
                    permit.hash_with_witness(witness, witness_type_string),
                    signature,
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
                    permit.hash_with_witness(witness, witness_type_string),
                    signature,
                );
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Nonces: UnorderedNoncesComponent::HasComponent<TContractState>,
        impl Metadata: SNIP12Metadata,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn _permit_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            data_hash: felt252,
            signature: Array<felt252>,
        ) {
            let requested_amount = transfer_details.requested_amount;
            /// TODO: custom error
            assert(
                starknet::get_block_timestamp() <= permit.deadline.try_into().unwrap(),
                'SignatureExpired',
            );
            assert(requested_amount <= permit.permitted.amount, 'InvalidAmount');

            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component._use_unordered_nonce(owner, permit.nonce);

            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            /// TODO: custom error
            assert(
                src6_dispatcher.is_valid_signature(data_hash, signature) == starknet::VALIDATED,
                'InvalidSignature',
            );
            /// TODO: Assert return value
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
            assert(
                starknet::get_block_timestamp() <= permit.deadline.try_into().unwrap(),
                'SignatureExpired',
            );
            assert(permit.permitted.len() == transfer_details.len(), 'LengthMismatch');

            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component._use_unordered_nonce(owner, permit.nonce);

            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            /// TODO: custom error
            assert(
                src6_dispatcher.is_valid_signature(data_hash, signature) == starknet::VALIDATED,
                'InvalidSignature',
            );

            for (permitted, transfer_detail) in permit.permitted.into_iter().zip(transfer_details) {
                let requested_amount = *transfer_detail.requested_amount;
                assert(requested_amount <= *permitted.amount, 'InvalidAmount');

                if requested_amount > 0 {
                    /// TODO: Assert return value
                    IERC20Dispatcher { contract_address: *permitted.token }
                        .transfer_from(owner, *transfer_detail.to, requested_amount);
                }
            }
        }
    }
}
