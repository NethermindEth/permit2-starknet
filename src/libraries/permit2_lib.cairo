#[starknet::component]
pub mod Permit2Lib {
    use core::num::traits::Bounded;
    use openzeppelin_token::erc20::interface::{
        IERC20PermitSafeDispatcher, IERC20PermitSafeDispatcherTrait, IERC20SafeDispatcher,
        IERC20SafeDispatcherTrait,
    };
    use permit2::interfaces::allowance_transfer::{
        IAllowanceTransferDispatcher, IAllowanceTransferDispatcherTrait, PermitDetails,
        PermitSingle,
    };
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    /// Permit2 contract address
    //const permit2: IAllowanceTransferDispatcher = IAllowanceTransferDispatcher {
    //    contract_address: 0xbeef.try_into().unwrap(),
    //};

    #[storage]
    pub struct Storage {
        _permit2: IAllowanceTransferDispatcher,
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initialize the Permit2 contract address
        /// NOTE: Can remove this once permit2 address is fixed and use const above
        fn _initialize(ref self: ComponentState<TContractState>, permit2_address: ContractAddress) {
            let _permit2 = IAllowanceTransferDispatcher { contract_address: permit2_address };
            self._permit2.write(_permit2);
        }

        /// Transfer a given amount of tokens from one user to another.
        ///
        /// Parameters:
        ///
        /// - `token`: The token to transfer.
        /// - `from`: The user to transfer from.
        /// - `to`: The` user to transfer to.
        /// - `amount`: The amount to transfer.
        #[feature("safe_dispatcher")]
        fn _transfer_from2(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
        ) {
            // First try IERC20Component::transfer_from()
            let erc20 = IERC20SafeDispatcher { contract_address: token };
            let status = erc20.transfer_from(from, to, amount);

            // If the call fails, fall back to Permit2::transfer_from()
            if (!status.is_ok()) {
                self._permit2.read().transfer_from(from, to, amount, token);
                //permit2.transfer_from(from, to, amount, token);
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
        #[feature("safe_dispatcher")]
        fn _permit2(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u64,
            signature: Array<felt252>,
        ) {
            let erc20 = IERC20PermitSafeDispatcher { contract_address: token };
            let domain_separator = erc20.DOMAIN_SEPARATOR();

            // First try ERC20Permit::permit() if the token supports it
            if (domain_separator.is_ok()) {
                let status = erc20.permit(owner, spender, amount, deadline, signature.span());

                // If the permit succeeds, we are done
                if (status.is_ok()) {
                    return;
                }
            }

            // If there is no domain separator or permit fails, fall back to Permit2::permit()
            self._simple_permit2(token, owner, spender, amount, deadline.into(), signature);
        }

        /// Simple unlimited permit on the Permit2 contract.
        ///
        /// Parameters:
        /// - `token`: The token to permit spending.
        /// - `owner`: The user to permit spending from.
        /// - `spender`: The user to permit spending to.
        /// - `amount`: The amount to permit spending.
        /// - `deadline`: The timestamp after which the signature is no longer valid.
        /// - `signature`: The signature of the pemrit
        fn _simple_permit2(
            ref self: ComponentState<TContractState>,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            deadline: u256,
            signature: Array<felt252>,
        ) {
            let (_, _, nonce) = self._permit2.read().allowance(owner, token, spender);

            //self.permit2
            self
                ._permit2
                .read()
                .permit(
                    owner,
                    PermitSingle {
                        details: PermitDetails {
                            token, amount, expiration: Bounded::<u64>::MAX, nonce,
                        },
                        spender,
                        sig_deadline: deadline,
                    },
                    signature,
                );
        }
    }
}

