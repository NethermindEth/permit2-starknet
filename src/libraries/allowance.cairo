use starknet::storage::{Mutable, StoragePath, StoragePointerReadAccess, StoragePointerWriteAccess};
use crate::allowance_transfer::interface::Allowance;

pub trait AllowanceTrait {
    const BLOCK_TIMESTAMP_EXPIRATION: u64;

    fn update_all(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64, nonce: u64,
    );
    fn update_amount_and_expiration(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64,
    );
}

impl AllowanceImpl of AllowanceTrait {
    const BLOCK_TIMESTAMP_EXPIRATION: u64 = 0;

    fn update_all(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64, nonce: u64,
    ) {
        let stored_nonce = nonce + 1;

        let stored_expiration = if expiration == Self::BLOCK_TIMESTAMP_EXPIRATION {
            starknet::get_block_timestamp()
        } else {
            expiration
        };

        self.write(Allowance { amount, expiration: stored_expiration, nonce: stored_nonce });
    }

    fn update_amount_and_expiration(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64,
    ) {
        let mut allowance = self.read();
        allowance
            .expiration =
                if expiration == Self::BLOCK_TIMESTAMP_EXPIRATION {
                    starknet::get_block_timestamp()
                } else {
                    expiration
                };

        allowance.amount = amount;
        self.write(allowance);
    }
}


#[cfg(test)]
pub mod allowance_unit_test {
    use core::num::traits::Bounded;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{Allowance, AllowanceTrait};

    fn FROM() -> ContractAddress {
        'FROM'.try_into().unwrap()
    }
    fn SPENDER() -> ContractAddress {
        'SPENDER'.try_into().unwrap()
    }
    fn TOKEN() -> ContractAddress {
        'TOKEN'.try_into().unwrap()
    }

    #[starknet::contract]
    mod contract_with_allowance {
        use starknet::ContractAddress;
        use starknet::storage::Map;
        use super::super::Allowance;

        #[storage]
        pub struct Storage {
            pub allowance: Map<(ContractAddress, ContractAddress, ContractAddress), Allowance>,
        }
    }

    #[test]
    #[fuzzer]
    fn test_should_update_amount_and_expiration_randomly(amount: u256, expiration: u64) {
        let mut allowance_contract_state = contract_with_allowance::contract_state_for_testing();
        let mut allowance_storage = allowance_contract_state
            .allowance
            .entry((FROM(), TOKEN(), SPENDER()));
        let nonce_before = allowance_storage.read().nonce;
        allowance_storage.update_amount_and_expiration(amount, expiration);

        let timestamp_after_upgrade = if expiration == 0 {
            starknet::get_block_timestamp()
        } else {
            expiration
        };

        let allowance_after = allowance_storage.read();
        assert_eq!(allowance_after.amount, amount);
        assert_eq!(allowance_after.expiration, timestamp_after_upgrade);
        assert_eq!(allowance_after.nonce, nonce_before, "Nonce shouldn't change");
    }


    #[test]
    #[fuzzer]
    fn test_should_update_all(amount: u256, expiration: u64, mut nonce: u64) {
        nonce %= Bounded::MAX;
        let mut allowance_contract_state = contract_with_allowance::contract_state_for_testing();
        let mut allowance_storage = allowance_contract_state
            .allowance
            .entry((FROM(), TOKEN(), SPENDER()));
        allowance_storage.update_all(amount, expiration, nonce);

        let nonce_after_upgrade = nonce + 1;

        let timestamp_after_upgrade = if expiration == 0 {
            starknet::get_block_timestamp()
        } else {
            expiration
        };

        let allowance_after = allowance_storage.read();
        assert_eq!(allowance_after.amount, amount);
        assert_eq!(allowance_after.expiration, timestamp_after_upgrade);
        assert_eq!(allowance_after.nonce, nonce_after_upgrade);
    }

    #[test]
    #[fuzzer]
    fn test_should_pack_and_unpack(amount: u256, expiration: u64, mut nonce: u64) {
        let mut allowance_contract_state = contract_with_allowance::contract_state_for_testing();
        let mut allowance_storage = allowance_contract_state
            .allowance
            .entry((FROM(), TOKEN(), SPENDER()));
        let expected_allowance = Allowance { amount, expiration, nonce };
        allowance_storage.write(expected_allowance);
        let stored_allowance = allowance_storage.read();
        assert_eq!(stored_allowance, expected_allowance, "Allowances does not match");
    }
}
