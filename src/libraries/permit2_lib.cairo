use core::num::traits::Bounded;
use openzeppelin_token::erc20::interface::{
    IERC20PermitSafeDispatcher, IERC20PermitSafeDispatcherTrait, IERC20SafeDispatcher,
    IERC20SafeDispatcherTrait,
};
use crate::interfaces::allowance_transfer::{
    IAllowanceTransferDispatcher, IAllowanceTransferDispatcherTrait, PermitDetails, PermitSingle,
};
use starknet::ContractAddress;


// NOTE: Once there is a live contract, remove `permit2` and replace with the actual address
pub trait Permit2Lib {
    /// Transfer a given amount of tokens from one user to another.
    ///
    /// Parameters:
    ///
    /// - `token`: The token to transfer.
    /// - `from`: The user to transfer from.
    /// - `to`: The` user to transfer to.
    /// - `amount`: The amount to transfer.
    fn transfer_from2(
        token: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        permit2: ContractAddress,
    );

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
    fn permit2(
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Array<felt252>,
        permit2: ContractAddress,
    );

    /// Simple unlimited permit on the Permit2 contract.
    ///
    /// Parameters:
    /// - `token`: The token to permit spending.
    /// - `owner`: The user to permit spending from.
    /// - `spender`: The user to permit spending to.
    /// - `amount`: The amount to permit spending.
    /// - `deadline`: The timestamp after which the signature is no longer valid.
    /// - `signature`: The signature of the pemrit
    fn simple_permit2(
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u256,
        signature: Array<felt252>,
        permit2: ContractAddress,
    );
}

pub impl Permit2LibImpl of Permit2Lib {
    #[feature("safe_dispatcher")]
    fn transfer_from2(
        token: ContractAddress,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        permit2: ContractAddress,
    ) {
        // First try IERC20Component::transfer_from()
        let status = IERC20SafeDispatcher { contract_address: token }
            .transfer_from(from, to, amount);

        // If the call fails, fall back to Permit2::transfer_from()
        if (!status.is_ok()) {
            IAllowanceTransferDispatcher { contract_address: permit2 }
                .transfer_from(from, to, amount, token);
        }
    }

    #[feature("safe_dispatcher")]
    fn permit2(
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u64,
        signature: Array<felt252>,
        permit2: ContractAddress,
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

        //simple_permit2(token, owner, spender, amount, deadline.into(), signature, permit2);
        //possible ?

        // If there is no domain separator or permit fails, fall back to Permit2::permit()
        let permit2 = IAllowanceTransferDispatcher { contract_address: permit2 };
        let (_, _, nonce) = permit2.allowance(owner, token, spender);
        permit2
            .permit(
                owner,
                PermitSingle {
                    details: PermitDetails {
                        token, amount, expiration: Bounded::<u64>::MAX, nonce,
                    },
                    spender,
                    sig_deadline: deadline.into(),
                },
                signature,
            );
    }

    fn simple_permit2(
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        amount: u256,
        deadline: u256,
        signature: Array<felt252>,
        permit2: ContractAddress,
    ) {
        let permit2 = IAllowanceTransferDispatcher { contract_address: permit2 };
        let (_, _, nonce) = permit2.allowance(owner, token, spender);

        permit2
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

