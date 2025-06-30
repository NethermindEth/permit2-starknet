#[starknet::component]
pub mod AllowanceTransferComponent {
    use core::num::traits::Bounded;
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use permit2::allowance_transfer::interface::{
        Allowance, AllowanceTransferDetails, IAllowanceTransfer, PermitBatch, PermitDetails,
        PermitSingle, TokenSpenderPair, errors, events,
    };
    use permit2::allowance_transfer::snip12_utils::{
        PermitBatchStructHash, PermitDetailsStructHash, PermitSingleStructHash,
    };
    use permit2::libraries::allowance::AllowanceTrait;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    /// STORAGE ///

    #[storage]
    pub struct Storage {
        allowance: Map<(ContractAddress, ContractAddress, ContractAddress), Allowance>,
    }

    /// EVENTS ///

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AllowanceTransferEvent: events::AllowanceTransferEvent,
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
            let owner = starknet::get_caller_address();
            let mut allowed = self.allowance.entry((owner, token, spender));
            allowed.update_amount_and_expiration(amount, expiration);
            self
                .emit(
                    events::AllowanceTransferEvent::Approval(
                        events::Approval { owner: owner, token, spender, amount, expiration },
                    ),
                )
        }

        fn permit(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            permit_single: PermitSingle,
            signature: Array<felt252>,
        ) {
            assert(
                starknet::get_block_timestamp() <= permit_single.sig_deadline.try_into().unwrap(),
                errors::SignatureExpired,
            );

            let message_hash = permit_single.get_message_hash(owner);
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };
            assert(
                src6_dispatcher.is_valid_signature(message_hash, signature) == starknet::VALIDATED,
                errors::InvalidSignature,
            );
            self._update_approval(permit_single.details, owner, permit_single.spender);
        }

        fn permit_batch(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            permit_batch: PermitBatch,
            signature: Array<felt252>,
        ) {
            assert(
                starknet::get_block_timestamp() <= permit_batch.sig_deadline.try_into().unwrap(),
                errors::SignatureExpired,
            );

            let message_hash = permit_batch.get_message_hash(owner);
            let src6_dispatcher = ISRC6Dispatcher { contract_address: owner };

            assert(
                src6_dispatcher.is_valid_signature(message_hash, signature) == starknet::VALIDATED,
                errors::InvalidSignature,
            );

            let spender = permit_batch.spender;
            for permit_single in permit_batch.details {
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
            let owner = starknet::get_caller_address();

            for approval in approvals {
                let allowance_storage = self
                    .allowance
                    .entry((owner, approval.token, approval.spender));
                let mut allowed = allowance_storage.read();
                allowed.amount = 0;
                allowance_storage.write(allowed);
                self
                    .emit(
                        events::AllowanceTransferEvent::Lockdown(
                            events::Lockdown {
                                owner, token: approval.token, spender: approval.spender,
                            },
                        ),
                    );
            }
        }

        fn invalidate_nonces(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            spender: ContractAddress,
            new_nonce: u64,
        ) {
            let owner = starknet::get_caller_address();
            let allowance_storage = self.allowance.entry((owner, token, spender));
            let mut allowed = allowance_storage.read();
            let old_nonce = allowed.nonce;
            assert(new_nonce > old_nonce, errors::InvalidNonce);
            /// Assert delta is less than u16 max.
            assert(new_nonce - old_nonce < Bounded::<u16>::MAX.into(), errors::ExcessiveNonceDelta);
            allowed.nonce = new_nonce;
            allowance_storage.write(allowed);
            self
                .emit(
                    events::AllowanceTransferEvent::NonceInvalidation(
                        events::NonceInvalidation { owner, token, spender, new_nonce, old_nonce },
                    ),
                );
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
            assert(starknet::get_block_timestamp() <= allowed.expiration, errors::AllowanceExpired);

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
            assert(details.nonce == allowance_storage.read().nonce, errors::InvalidNonce);

            allowance_storage.update_all(details.amount, details.expiration, details.nonce);
            self
                .emit(
                    events::AllowanceTransferEvent::Permit(
                        events::Permit {
                            owner,
                            token: details.token,
                            spender,
                            amount: details.amount,
                            expiration: details.expiration,
                            nonce: details.nonce,
                        },
                    ),
                );
        }
    }
}
