#[starknet::component]
pub mod AllowanceTransferComponent {
    use core::num::traits::Bounded;
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use permit2::interfaces::allowance_transfer::{
        AllowanceTransferDetails, IAllowanceTransfer, PermitBatch, PermitDetails, PermitSingle,
        TokenSpenderPair,
    };
    use permit2::libraries::allowance::{Allowance, AllowanceTrait};
    use permit2::snip12_utils::permits::{
        PermitBatchStructHash, PermitDetailsStructHash, PermitSingleStructHash,
    };
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, VALIDATED, get_block_timestamp, get_caller_address};

    /// ERRORS ///
    pub mod Errors {
        pub const SignatureExpired: felt252 = 'AT: signature expired';
        pub const AllowanceExpired: felt252 = 'AT: allowance expired';
        pub const InvalidNonce: felt252 = 'AT: invalid nonce';
        pub const InvalidSignature: felt252 = 'AT: invalid signature';
        pub const ExcessiveNonceDelta: felt252 = 'AT: excessive nonce delta';
    }

    /// STORAGE ///
    #[storage]
    pub struct Storage {
        allowance: Map<(ContractAddress, ContractAddress, ContractAddress), Allowance>,
    }

    /// EVENTS ///
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NonceInvalidation: NonceInvalidation,
        Approval: Approval,
        Permit: Permit,
        Lockdown: Lockdown,
    }

    /// Emited when the owner successfully invalidates an ordered nonce.
    #[derive(Drop, starknet::Event)]
    pub struct NonceInvalidation {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub new_nonce: u64,
        pub old_nonce: u64,
    }


    /// Emitted when the owner successfully sets permissions on a token for the spender.
    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub amount: u256,
        pub expiration: u64,
    }

    /// Emitted an event when the owner successfully sets permissions using a permit signature on a
    /// token for the spender.
    #[derive(Drop, starknet::Event)]
    pub struct Permit {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub token: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        /// NOTE: uint160 in sol
        pub amount: u256,
        pub expiration: u64,
        pub nonce: u64,
    }

    /// Emitted an event when the owner sets the allowance back to 0 with the lockdown function.
    #[derive(starknet::Event, Drop)]
    pub struct Lockdown {
        #[key]
        pub owner: ContractAddress,
        pub token: ContractAddress,
        pub spender: ContractAddress,
    }


    /// PUBLIC ///
    #[embeddable_as(AllowanceTransferImpl)]
    impl AllowanceTransfer<
        TContractState,
        impl Metadata: SNIP12Metadata,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IAllowanceTransfer<ComponentState<TContractState>> {
        /// Reads ///

        fn allowance(
            self: @ComponentState<TContractState>,
            user: ContractAddress,
            token: ContractAddress,
            spender: ContractAddress,
        ) -> (u256, u64, u64) {
            let packed_allowance = self.allowance.entry((user, token, spender)).read();
            (packed_allowance.amount, packed_allowance.expiration, packed_allowance.nonce)
        }

        /// Writes ///

        fn approve(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            expiration: u64,
        ) {
            let owner = get_caller_address();
            let mut allowance = self.allowance.entry((owner, token, spender));
            allowance.update_amount_and_expiration(amount, expiration);
            self.emit(Approval { owner: owner, token, spender, amount, expiration })
        }

        fn permit(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            permit: PermitSingle,
            signature: Array<felt252>,
        ) {
            assert(
                get_block_timestamp() <= permit.sig_deadline.try_into().unwrap(),
                Errors::SignatureExpired,
            );

            let message_hash = permit.get_message_hash(owner);
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            assert(
                src6_dispatcher.is_valid_signature(message_hash, signature) == VALIDATED,
                Errors::InvalidSignature,
            );
            self._update_approval(permit.details, owner, permit.spender);
        }

        fn permit_batch(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            permit: PermitBatch,
            signature: Array<felt252>,
        ) {
            assert(
                get_block_timestamp() <= permit.sig_deadline.try_into().unwrap(),
                Errors::SignatureExpired,
            );

            let message_hash = permit.get_message_hash(owner);
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };

            assert(
                src6_dispatcher.is_valid_signature(message_hash, signature) == VALIDATED,
                Errors::InvalidSignature,
            );

            let spender = permit.spender;
            for permit_single in permit.details {
                self._update_approval(*permit_single, owner, spender)
            }
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            token: ContractAddress,
        ) {
            self._transfer(from, to, amount, token);
        }

        fn batch_transfer_from(
            ref self: ComponentState<TContractState>,
            transfer_details: Array<AllowanceTransferDetails>,
        ) {
            for detail in transfer_details {
                self._transfer(detail.from, detail.to, detail.amount, detail.token);
            }
        }

        fn lockdown(ref self: ComponentState<TContractState>, approvals: Array<TokenSpenderPair>) {
            let owner = get_caller_address();

            for approval in approvals {
                let allowance_storage = self
                    .allowance
                    .entry((owner, approval.token, approval.spender));
                let mut allowed = allowance_storage.read();
                allowed.amount = 0;
                allowance_storage.write(allowed);
                self.emit(Lockdown { owner, token: approval.token, spender: approval.spender });
            }
        }

        fn invalidate_nonces(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            spender: ContractAddress,
            new_nonce: u64,
        ) {
            let owner = get_caller_address();
            let allowance_storage = self.allowance.entry((owner, token, spender));
            let mut allowed = allowance_storage.read();
            let old_nonce = allowed.nonce;
            assert(new_nonce > old_nonce, Errors::InvalidNonce);
            /// Assert delta is less than u16 max.
            assert(new_nonce - old_nonce < Bounded::<u16>::MAX.into(), Errors::ExcessiveNonceDelta);
            allowed.nonce = new_nonce;
            allowance_storage.write(allowed);
            self.emit(NonceInvalidation { owner, token, spender, new_nonce, old_nonce });
        }
    }

    /// INTERNAL ///
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +SNIP12Metadata, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn _transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            token: ContractAddress,
        ) {
            let mut allowance_storage = self
                .allowance
                .entry((from, token, starknet::get_caller_address()));
            let mut allowed = allowance_storage.read();
            assert(get_block_timestamp() <= allowed.expiration, Errors::AllowanceExpired);

            if allowed.amount != Bounded::MAX {
                allowed.amount -= amount;
            }
            allowance_storage.write(allowed);

            IERC20Dispatcher { contract_address: token }.transfer_from(from, to, amount);
        }


        fn _update_approval(
            ref self: ComponentState<TContractState>,
            details: PermitDetails,
            owner: ContractAddress,
            spender: ContractAddress,
        ) {
            let mut allowance_storage = self.allowance.entry((owner, details.token, spender));
            assert(details.nonce == allowance_storage.read().nonce, Errors::InvalidNonce);

            allowance_storage.update_all(details.amount, details.expiration, details.nonce);
            self
                .emit(
                    Permit {
                        owner,
                        token: details.token,
                        spender,
                        amount: details.amount,
                        expiration: details.expiration,
                        nonce: details.nonce,
                    },
                );
        }
    }
}
