#[starknet::component]
pub mod SignatureTransferComponent {
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use crate::components::unordered_nonces::UnorderedNoncesComponent;
    use crate::components::unordered_nonces::UnorderedNoncesComponent::{
        InternalTrait as NoncesInternalTrait, UnorderedNoncesImpl,
    };
    use crate::interfaces::signature_transfer::{
        ISignatureTransfer, PermitBatchTransferFrom, PermitTransferFrom, SignatureTransferDetails,
    };
    use crate::snip12_utils::permits::{
        OffchainMessageHashWitnessTrait, PermitBatchStructHash, PermitBatchTransferFromStructHash,
        PermitBatchTransferFromStructHashWitness, PermitSingleStructHash,
        PermitTransferFromStructHash, PermitTransferFromStructHashWitness,
        TokenPermissionsStructHash,
    };
    use starknet::ContractAddress;

    /// ERRORS ///
    pub mod Errors {
        pub const SIGNATURE_EXPIRED: felt252 = 'ST: signature expired';
        pub const LENGTH_MISMATCH: felt252 = 'ST: length mismatch';
        pub const INVALID_SIGNATURE: felt252 = 'ST: invalid signature';
        pub const INVALID_AMOUNT: felt252 = 'ST: invalid amount';
    }

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
        /// Internal function to transfer a token using a signed permit message.
        ///
        /// Parameters:
        ///
        /// - 'permit': The permit data signed over by the owner.
        /// - 'transfer_details': The spender's requested transfer details for the permitted token.
        /// - 'owner': The owner of the tokens to transfer.
        /// - 'data_hash': The hash of the permit data to verify the signature against.
        /// - 'signature': The signature to verify.
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
                Errors::SIGNATURE_EXPIRED,
            );

            // Validate transfer amount <= permitted amount
            let requested_amount = transfer_details.requested_amount;
            assert(requested_amount <= permit.permitted.amount, Errors::INVALID_AMOUNT);

            // Use nonce
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component._use_unordered_nonce(owner, permit.nonce);

            // Validate signature
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            let is_valid = src6_dispatcher.is_valid_signature(data_hash, signature);
            assert(is_valid == starknet::VALIDATED, Errors::INVALID_SIGNATURE);

            // Transfer tokens
            IERC20Dispatcher { contract_address: permit.permitted.token }
                .transfer_from(owner, transfer_details.to, requested_amount);
        }

        /// Internal function to transfer multiple tokens using a signed permit message.
        ///
        /// Parameters:
        ///
        /// - 'permit': The permit data signed over by the owner.
        /// - 'transfer_details': Specifies the recipient and requested amount for each token
        /// transfer.
        /// - 'owner': The owner of the tokens to transfer.
        /// - 'data_hash': The hash of the permit data to verify the signature against.
        /// - 'signature': The signature to verify.
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
                Errors::SIGNATURE_EXPIRED,
            );

            // Validate permit & transfer detail lengths
            assert(permit.permitted.len() == transfer_details.len(), Errors::LENGTH_MISMATCH);

            // Use nonce
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component._use_unordered_nonce(owner, permit.nonce);

            // Validate signature
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            let is_valid = src6_dispatcher.is_valid_signature(data_hash, signature);
            assert(is_valid == starknet::VALIDATED, Errors::INVALID_SIGNATURE);

            // Iterate over each permitted token and transfer detail
            let mut i = 0_usize;
            while i != permit.permitted.len() {
                let permitted = permit.permitted.get(i).unwrap();
                let transfer_detail = transfer_details.get(i).unwrap();
                // Validate requested amount <= permitted amount
                let requested_amount = transfer_detail.requested_amount;
                assert(requested_amount <= permitted.amount, 'InvalidAmount');

                // Transfer tokens
                if requested_amount > 0 {
                    IERC20Dispatcher { contract_address: permitted.token }
                        .transfer_from(owner, transfer_detail.to, requested_amount);
                }

                i += 1;
            };
        }
    }
}
