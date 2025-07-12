use starknet::storage::{Mutable, StoragePath, StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::storage_access::StorePacking;

pub trait AllowanceTrait {
    const BLOCK_TIMESTAMP_EXPIRATION: u64;

    fn update_all(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64, nonce: u64,
    );
    fn update_amount_and_expiration(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64,
    );
}

/// The saved permissions
/// @dev This info is saved per owner, per token, per spender and all signed over in the permit
/// message
/// @dev Setting amount to type(uint256).max sets an unlimited approval
#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub struct Allowance {
    pub amount: u256,
    pub expiration: u64,
    pub nonce: u64,
}

impl AllowancePacking of StorePacking<Allowance, (u256, u64, u64)> {
    fn pack(value: Allowance) -> (u256, u64, u64) {
        (value.amount, value.expiration, value.nonce)
    }

    fn unpack(value: (u256, u64, u64)) -> Allowance {
        let (amount, expiration, nonce) = value;
        Allowance { amount, expiration, nonce }
    }
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
pub mod allowance_unit_tests {
    use core::num::traits::Bounded;
    use starknet::ContractAddress;
    use starknet::storage::{
        Mutable, StoragePath, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
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

    fn setup() -> StoragePath<Mutable<Allowance>> {
        let mut allowance_contract_state = contract_with_allowance::contract_state_for_testing();
        let mut allowance_storage = allowance_contract_state
            .allowance
            .entry((FROM(), TOKEN(), SPENDER()));

        return allowance_storage;
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
        let mut allowance_storage = setup();
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
        let mut allowance_storage = setup();

        allowance_storage.update_all(amount, expiration, nonce);

        let timestamp_after = if expiration == 0 {
            starknet::get_block_timestamp()
        } else {
            expiration
        };
        let allowance_after = allowance_storage.read();

        assert_eq!(allowance_after.amount, amount);
        assert_eq!(allowance_after.expiration, timestamp_after);
        assert_eq!(allowance_after.nonce, nonce + 1);
    }

    #[test]
    #[fuzzer]
    fn test_should_pack_and_unpack(amount: u256, expiration: u64, mut nonce: u64) {
        let mut allowance_storage = setup();
        let expected_allowance = Allowance { amount, expiration, nonce };

        allowance_storage.write(expected_allowance);

        let stored_allowance = allowance_storage.read();
        assert_eq!(stored_allowance, expected_allowance, "Allowances does not match");
    }
}
