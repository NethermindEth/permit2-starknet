// Fallback: transfer_from, permit1, then permit2,

use core::num::traits::Bounded;
use openzeppelin_token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20PermitDispatcher, IERC20PermitDispatcherTrait,
};
use openzeppelin_token::erc20::snip12_utils::permit::Permit;
use permit2::components::interfaces::allowance_transfer::{PermitDetails, PermitSingle};
use starknet::ContractAddress;

#[starknet::component]
pub mod Permit2Lib {
    use permit2::interfaces::allowance_transfer::{
        IAllowanceTransferDispatcher, IAllowanceTransferDispatcherTrait,
    };
    use permit2::interfaces::unordered_nonces::IUnorderedNonces;
    use permit2::libraries::bitmap::{BitmapPackingTrait, BitmapTrait};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    const permit2: IAllowanceTransferDispatcher = IAllowanceTransferDispatcher {
        contract_address: 0xbeef.try_into().unwrap(),
    };

    /// NOTE: Can remove storage and constructor once permit2 address is fixed
    #[storage]
    struct Storage {
        permit2: ContractAddress,
        #[substorage(v0)]
        permit2_lib: Permit2Lib::Storage,
    }


    #[constructor]
    fn constructor(ref self: ContractState, permit2: ContractAddress) {
        self.permit2.write(permit2);
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Transfer a given amount of tokens from one user to another.
        ///
        /// Parameters:
        ///
        /// - `token`: The token to transfer.
        /// - `from`: The user to transfer from.
        /// - `to`: The` user to transfer to.
        /// - `amount`: The amount to transfer.
        fn _transfer_from2(
            ref self: ComponentState<TContractState>,
            token: IERC20Dispatcher,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) {
            let erc20 = IERC20PermitDispatcher { contract_address: token };
            let success = erc20.transfer_from(from, to, amount);

            if (!success) {
                permit2.transfer_from(from, to, amount)
            }
        }

        /// Permit a user to spend a given amount of another user's tokens via native EIP-2612
        /// permit if possible, falling back to Permit2 if native permit fails or is not implemented
        /// on the token.
        ///
        /// Parameters:
        ///
        /// `token`: The token to permit spending.
        /// `owner`: The user to permit spending from.
        /// `spender`: The user to permit spending to.
        /// `amount`: The amount to permit spending.
        /// `deadline`:  The timestamp after which the signature is no longer valid.
        /// `signature`:  The signature of the permit.
        fn _permit2(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u256,
            signature: Span<felt252>,
        ) { // Get token domain seperator
            // If success, try to call erc20::permit

            // use safe dispatcher ? can we yet ?
            let erc20 = IERC20PermitDispatcher { contract_address: token };
            let domain_seperator = erc20.DOMAIN_SEPERATOR();

            if (domain_seperator) {
                erc20.permit(owner, spender, amount, deadline, signature);
            } else {
                // Get domain seperator if it exists
                // use safe dispatcher ? can we yet ?
                let erc20 = IERC20PermitDispatcher { contract_address: token };
                let domain_seperator = erc20.DOMAIN_SEPERATOR();

                // If there is a domain seperator, try class ERC20Permit::permit()
                if (domain_seperator) {
                    erc20.permit(owner, spender, amount, deadline, signature);
                } // If no domain seperator, use Permit2::permit()
                else {
                    self._permit2_simple(token, owner, spender, amount, deadline, signature);
                }
            }
        }

        fn _simple_permit2(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u256,
            signature: Span<felt252>,
        ) {
            let (_, _, nonce) = permit2.allowance(owner, token, spender);

            permit2
                .permit(
                    owner,
                    PermitSingle {
                        details: PermitDetails {
                            token,
                            amount,
                            expiration: Bounded::<
                                u256,
                            >::MAX, // Use an unlimited expiration because it most closely mimics how a standard approval works.
                            nonce,
                        },
                        spender,
                        sig_deadline: deadline,
                    },
                    signature,
                );
        }
    }
}

