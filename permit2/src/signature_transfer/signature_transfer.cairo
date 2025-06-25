#[starknet::component]
pub mod SignatureTransferComponent {
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use permit2::signature_transfer::interface::{
        ISignatureTransfer, PermitBatchTransferFrom, PermitTransferFrom, SignatureTransferDetails,
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    pub struct Storage {
        pub nonce_bitmap: Map<(ContractAddress, u256), u256>,
    }

    /// EVENTS ///

    #[event]
    #[derive(starknet::Event, Drop)]
    pub enum Event {
        UnorderedNonceInvalidation: UnorderedNonceInvalidation,
    }

    /// @notice Emits an event when the owner successfully invalidates an unordered nonce.
    #[derive(starknet::Event, Drop)]
    pub struct UnorderedNonceInvalidation {
        #[key]
        owner: ContractAddress,
        word: u256,
        mask: u256,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn _use_unordered_nonce(ref self: TContractState, owner: ContractAddress, nonce: u256) {}
        fn _assert_account_is_src5(ref self: TContractState, account: ContractAddress) -> bool {
            // https://medium.com/starknet-edu/account-abstraction-on-starknet-part-i-2ff84c6a3c30#:~:text=1270010605630597976495846281167968799381097569185364931397797212080166453709

            // @todo
            // check src5
            //    let src5_id =
            //        1270010605630597976495846281167968799381097569185364931397797212080166453709;

            false
        }

        fn _validate_signature(
            ref self: TContractState,
            signer: ContractAddress,
            hash: felt252,
            signature: Array<felt252>,
        ) {
            let dispatcher = ISRC6Dispatcher { contract_address: signer };
            let result = dispatcher.is_valid_signature(hash, signature);
            assert(result == 'VALID' || result == 1, 'Invalid signature');
        }


        fn _permit_transfer_from(
            ref self: TContractState,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            data_hash: felt252,
            signature: Array<felt252>,
        ) {
            let requested_amount = transfer_details.requested_amount;

            if (get_block_timestamp().into() > permit.deadline) {
                panic!("asdfasdf")
            }
            if (requested_amount > permit.permitted.amount) {
                panic!("Invalid amount");
            }

            self._use_unordered_nonce(owner, permit.nonce);

            self._validate_signature(owner, data_hash, signature);

            IERC20Dispatcher { contract_address: permit.permitted.token }
                .transfer_from(owner, transfer_details.to, requested_amount);
        }

        fn _permit_transfer_from_batch(
            ref self: TContractState,
            permit: PermitTransferFrom,
            transfer_details: Span<SignatureTransferDetails>,
            owner: ContractAddress,
            data_hash: bytes31,
            signature: ByteArray,
        ) {}
    }

    #[embeddable_as(SignatureTransferImpl)]
    impl SignatureTransfer<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ISignatureTransfer<ComponentState<TContractState>> {
        /// Reads ///
        fn nonce_bitmap(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u256,
        ) -> u256 {
            0
        }

        /// Writes ///

        fn permit_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            signature: ByteArray,
        ) {}

        fn permit_witness_transfer_from(
            ref self: ComponentState<TContractState>,
            permit: PermitTransferFrom,
            transfer_details: SignatureTransferDetails,
            owner: ContractAddress,
            witness: bytes31,
            witness_type_string: ByteArray,
            signature: ByteArray,
        ) {}

        fn permit_transfer_from_batch(
            ref self: ComponentState<TContractState>,
            permit: PermitBatchTransferFrom,
            transfer_details: Span<SignatureTransferDetails>,
            owner: ContractAddress,
            signature: ByteArray,
        ) {}

        fn permit_witness_transfer_from_batch(
            ref self: ComponentState<TContractState>,
            permit: PermitBatchTransferFrom,
            transfer_details: Span<SignatureTransferDetails>,
            owner: ContractAddress,
            witness: bytes31,
            witness_type_string: ByteArray,
            signature: ByteArray,
        ) {}

        fn invalidate_unordered_nonces(
            ref self: ComponentState<TContractState>, word_pos: u256, mask: u256,
        ) {}
    }
}
