use starknet::ContractAddress;
use crate::common::E18;

const DEFAULT_AMOUNT: u256 = 30 * E18;
const DEFAULT_NONCE: u64 = 0;

#[generate_trait]
pub impl AsAddressImpl of AsAddressTrait {
    /// Converts a felt252 to a ContractAddress as a constant function.
    ///
    /// Requirements:
    ///
    /// - `value` must be a valid contract address.
    const fn as_address(self: felt252) -> ContractAddress {
        self.try_into().expect('Invalid contract address')
    }
}

#[cfg(test)]
pub mod new_permits {
    use core::num::traits::Bounded;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{
        OffchainMessageHash, SNIP12HashSpanImpl, StarknetDomain,
    };
    use permit2::interfaces::allowance_transfer::{
        IAllowanceTransferDispatcher, IAllowanceTransferDispatcherTrait, PermitDetails,
        PermitSingle,
    };
    use permit2::libraries::permit2_lib::Permit2Lib;
    use permit2::permit2::Permit2::SNIP12MetadataImpl;
    use permit2::snip12_utils::permits::{
        PermitBatchStructHash, PermitBatchTransferFromStructHash,
        PermitBatchTransferFromStructHashWitness, PermitDetailsStructHash, PermitSingleStructHash,
        PermitTransferFromStructHash, PermitTransferFromStructHashWitness,
        TokenPermissionsStructHash,
    };
    use snforge_std::signature::SignerTrait;
    use snforge_std::signature::stark_curve::{
        StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use starknet::{ContractAddress, get_block_timestamp};
    use crate::common::E18;
    use crate::setup::{SetupPermit2Lib, setup_permit2_lib};
    use super::old_permits::test_standard_permit;
    use super::{AsAddressImpl, DEFAULT_AMOUNT};

    pub const cafe: ContractAddress = 0xcafe.as_address();

    pub fn setup() -> SetupPermit2Lib {
        let _setup = setup_permit2_lib();
        test_permit2_full(_setup);
        test_permit2_non_permit_fall_back(_setup);
        test_permit2_non_permit_token(_setup);
        test_standard_permit(_setup);
        return _setup;
    }

    fn test_permit2_full(setup: SetupPermit2Lib) {
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(setup.pk_owner.account.contract_address, setup.token.contract_address, cafe);

        // Create permit and sign it
        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        Permit2Lib::simple_permit2(
            setup.token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
    }

    fn test_permit2_non_permit_token(setup: SetupPermit2Lib) {
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(
                setup.pk_owner.account.contract_address,
                setup.non_permit_token.contract_address,
                cafe,
            );

        // Create permit and sign it
        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.non_permit_token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce: nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        Permit2Lib::simple_permit2(
            setup.non_permit_token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
    }

    fn test_permit2_non_permit_fall_back(setup: SetupPermit2Lib) {
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(
                setup.pk_owner.account.contract_address,
                setup.fallback_token.contract_address,
                cafe,
            );

        // Create permit and sign it
        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.fallback_token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce: nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        Permit2Lib::simple_permit2(
            setup.fallback_token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
    }

    #[test]
    fn test_standard_transfer_from() {
        let setup = setup();

        IERC20Dispatcher { contract_address: setup.token.contract_address }
            .transfer_from(setup.this, 0xbeef.as_address(), E18);
    }


    #[test]
    fn test_simple_permit2() {
        let setup = setup();
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(setup.pk_owner.account.contract_address, setup.token.contract_address, cafe);

        // Create permit and sign it
        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        Permit2Lib::simple_permit2(
            setup.token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
    }

    #[test]
    fn test_transfer_from2() {
        let setup = setup();

        Permit2Lib::transfer_from2(
            setup.token.contract_address,
            setup.this,
            0xb00b.as_address(),
            DEFAULT_AMOUNT,
            setup.permit2_lib.contract_address,
        );
    }

    fn create_domain(name: felt252, version: felt252) -> StarknetDomain {
        StarknetDomain {
            name, version, chain_id: starknet::get_tx_info().unbox().chain_id, revision: 1,
        }
    }
    //        let permit = PermitSingle {
    //            details: PermitDetails {
    //                token: setup.larger_ds_token.contract_address,
    //                amount: 1 * E18,
    //                expiration: Bounded::<u64>::MAX,
    //                nonce: nonce,
    //            },
    //            spender: cafe,
    //            sig_deadline: get_block_timestamp().into(),
    //        };
    //
    //        /// Create permit msg manually
    //        let permit_msg = PoseidonTrait::new()
    //            // Domain
    //            .update_with('StarkNet Message')
    //            .update_with(
    //                create_domain(SNIP12MetadataImpl::name(), SNIP12MetadataImpl::version())
    //                    .hash_struct(),
    //            )
    //            // Account
    //            .update_with(setup.pk_owner.account.contract_address)
    //            // Message
    //            .update_with(permit.hash_struct())
    //            .finalize();
    //
    //        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
    //        let signature = array![r, s];

    #[test]
    fn test_transfer_from2_full() {
        let setup = setup();

        start_cheat_caller_address(setup.permit2.contract_address, cafe);
        Permit2Lib::transfer_from2(
            setup.token.contract_address,
            setup.pk_owner.account.contract_address,
            0xb00b.as_address(),
            E18,
            setup.permit2.contract_address,
        );
        stop_cheat_caller_address(setup.permit2.contract_address);
    }

    #[test]
    fn test_transfer_from2_non_permit_token() {
        let setup = setup();

        start_cheat_caller_address(setup.permit2.contract_address, cafe);
        Permit2Lib::transfer_from2(
            setup.non_permit_token.contract_address,
            setup.pk_owner.account.contract_address,
            0xb00b.as_address(),
            E18,
            setup.permit2.contract_address,
        );
        stop_cheat_caller_address(setup.permit2.contract_address);
    }

    #[test]
    fn test_permit2_plus_transfer_from2_with_non_permit() {
        let setup = setup();
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(
                setup.pk_owner.account.contract_address,
                setup.non_permit_token.contract_address,
                cafe,
            );

        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.non_permit_token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        start_cheat_caller_address(setup.permit2.contract_address, cafe);
        Permit2Lib::permit2(
            setup.non_permit_token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );

        Permit2Lib::transfer_from2(
            setup.non_permit_token.contract_address,
            setup.pk_owner.account.contract_address,
            0xb00b.as_address(),
            1,
            setup.permit2.contract_address,
        );
        stop_cheat_caller_address(setup.permit2.contract_address);
    }

    #[test]
    fn test_permit2_plus_transfer_from2_with_non_permit_fallback() {
        let setup = setup();
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(
                setup.pk_owner.account.contract_address,
                setup.fallback_token.contract_address,
                cafe,
            );

        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.fallback_token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        start_cheat_caller_address(setup.permit2.contract_address, cafe);
        Permit2Lib::permit2(
            setup.fallback_token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
        Permit2Lib::transfer_from2(
            setup.fallback_token.contract_address,
            setup.pk_owner.account.contract_address,
            0xb00b.as_address(),
            E18,
            setup.permit2.contract_address,
        );
        stop_cheat_caller_address(setup.permit2.contract_address);
    }

    #[test]
    fn test_simple_permit2_plus_transfer_from2_with_non_permit() {
        let setup = setup();
        let (_, _, nonce) = IAllowanceTransferDispatcher {
            contract_address: setup.permit2.contract_address,
        }
            .allowance(
                setup.pk_owner.account.contract_address,
                setup.non_permit_token.contract_address,
                cafe,
            );

        let permit = PermitSingle {
            details: PermitDetails {
                token: setup.non_permit_token.contract_address,
                amount: E18,
                expiration: Bounded::<u64>::MAX,
                nonce,
            },
            spender: cafe,
            sig_deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        start_cheat_caller_address(setup.permit2.contract_address, cafe);
        Permit2Lib::simple_permit2(
            setup.non_permit_token.contract_address,
            setup.pk_owner.account.contract_address,
            cafe,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
        Permit2Lib::transfer_from2(
            setup.non_permit_token.contract_address,
            setup.pk_owner.account.contract_address,
            0xb00b.as_address(),
            E18,
            setup.permit2.contract_address,
        );
        stop_cheat_caller_address(setup.permit2.contract_address);
    }
}


#[cfg(test)]
pub mod old_permits {
    use openzeppelin_token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20PermitDispatcher,
        IERC20PermitDispatcherTrait,
    };
    use openzeppelin_token::erc20::snip12_utils::permit::Permit;
    use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
    use permit2::interfaces::allowance_transfer::{
        IAllowanceTransferDispatcher, IAllowanceTransferDispatcherTrait,
    };
    use permit2::libraries::permit2_lib::Permit2Lib;
    use permit2::snip12_utils::permits::{
        PermitBatchStructHash, PermitBatchTransferFromStructHash,
        PermitBatchTransferFromStructHashWitness, PermitDetailsStructHash, PermitSingleStructHash,
        PermitTransferFromStructHash, PermitTransferFromStructHashWitness,
        TokenPermissionsStructHash,
    };
    use snforge_std::signature::SignerTrait;
    use snforge_std::signature::stark_curve::{
        StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use starknet::{ContractAddress, get_block_timestamp};
    use crate::common::E18;
    use crate::mocks::mock_erc20_permit::MockERC20Permit::SNIP12MetadataImpl;
    use crate::setup::SetupPermit2Lib;
    use super::AsAddressImpl;
    use super::new_permits::setup;

    pub const amount: u256 = 1 * E18;
    const bob: ContractAddress = 0xb00b.as_address();

    pub fn test_standard_permit(setup: SetupPermit2Lib) {
        let nonce = IERC20PermitDispatcher { contract_address: setup.token.contract_address }
            .nonces(setup.pk_owner.account.contract_address);

        // Create permit(1) and sign it
        let permit = Permit {
            token: setup.token.contract_address,
            spender: bob,
            amount: E18,
            nonce,
            deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        setup
            .token
            .permit(
                setup.pk_owner.account.contract_address,
                bob,
                E18,
                get_block_timestamp().into(),
                signature.span(),
            );

        let allowance = IERC20Dispatcher { contract_address: setup.token.contract_address }
            .allowance(setup.pk_owner.account.contract_address, bob);

        assert_eq!(allowance, E18);
    }

    #[test]
    fn test_permit2() {
        let setup = setup();
        let nonce = IERC20PermitDispatcher { contract_address: setup.token.contract_address }
            .nonces(setup.pk_owner.account.contract_address);

        // Create permit(1) and sign it
        let permit = Permit {
            token: setup.token.contract_address,
            spender: bob,
            amount: 1 * E18,
            nonce,
            deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        Permit2Lib::permit2(
            setup.token.contract_address,
            setup.pk_owner.account.contract_address,
            bob,
            1 * E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        )
    }

    #[test]
    fn test_permit2_small_ds_no_revert() {
        let setup = setup();
        let nonce = IERC20PermitDispatcher { contract_address: setup.token.contract_address }
            .nonces(setup.pk_owner.account.contract_address);

        // Create permit(1) and sign it
        let permit = Permit {
            token: setup.token.contract_address,
            spender: bob,
            amount: E18,
            nonce: nonce,
            deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        setup
            .token
            .permit(
                setup.pk_owner.account.contract_address,
                bob,
                E18,
                get_block_timestamp().into(),
                signature.span(),
            );
    }

    #[test]
    fn test_permit2_plus_transfer_from2() {
        let setup = setup();
        let nonce = IERC20PermitDispatcher { contract_address: setup.token.contract_address }
            .nonces(setup.pk_owner.account.contract_address);

        // Create permit(1) and sign it
        let permit = Permit {
            token: setup.token.contract_address,
            spender: bob,
            amount: E18,
            nonce,
            deadline: get_block_timestamp().into(),
        };
        let permit_msg = permit.get_message_hash(setup.pk_owner.account.contract_address);
        let (r, s) = setup.pk_owner.key_pair.sign(permit_msg).unwrap();
        let signature = array![r, s];

        start_cheat_caller_address(setup.token.contract_address, bob);
        Permit2Lib::permit2(
            setup.token.contract_address,
            setup.pk_owner.account.contract_address,
            bob,
            E18,
            get_block_timestamp().into(),
            signature,
            setup.permit2.contract_address,
        );
        Permit2Lib::transfer_from2(
            setup.token.contract_address,
            setup.pk_owner.account.contract_address,
            bob,
            1,
            setup.permit2.contract_address,
        );
        stop_cheat_caller_address(setup.token.contract_address);
    }
}

