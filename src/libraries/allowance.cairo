use starknet::storage::{Mutable, StoragePath, StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::storage_access::StorePacking;

pub trait AllowanceTrait {
    const BLOCK_TIMESTAMP_EXPIRATION: u64;

    /// Updates all fields of an allowance: amount, expiration, and nonce.
    ///
    /// Parameters:
    ///
    /// - 'amount': The new approved amount.
    /// - 'expiration': The new expiration timestamp. If set to BLOCK_TIMESTAMP_EXPIRATION, uses
    /// current block timestamp.
    /// - 'nonce': The new nonce value.
    fn update_all(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64, nonce: u64,
    );
    /// Updates the amount and expiration of an allowance, leaving the nonce unchanged.
    ///
    /// Parameters:
    ///
    /// - 'amount': The new approved amount.
    /// - 'expiration': The new expiration timestamp. If set to BLOCK_TIMESTAMP_EXPIRATION, uses
    /// current block timestamp.
    fn update_amount_and_expiration(
        ref self: StoragePath<Mutable<Allowance>>, amount: u256, expiration: u64,
    );
}

/// The saved permissions.
///
/// This info is saved per owner, per token, per spender and all signed over in the permit
/// message.
///
/// Setting amount to type(uint256).max sets an unlimited approval.
#[derive(Drop, Copy, Serde, PartialEq, Debug)]
pub struct Allowance {
    pub amount: u256,
    pub expiration: u64,
    pub nonce: u64,
}

const SHIFT_128: u256 = 0x100000000000000000000000000000000;
const MASK_128: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

impl AllowancePacking of StorePacking<Allowance, (felt252, felt252)> {
    fn pack(value: Allowance) -> (felt252, felt252) {
        let low_and_expiration: u256 = value.amount.low.into()
            + (value.expiration.into() * SHIFT_128);
        let high_and_nonce: u256 = value.amount.high.into() + (value.nonce.into() * SHIFT_128);
        (low_and_expiration.try_into().unwrap(), high_and_nonce.try_into().unwrap())
    }

    fn unpack(value: (felt252, felt252)) -> Allowance {
        let (low_and_expiration, high_and_nonce) = value;

        let low = (low_and_expiration.into() & MASK_128).try_into().unwrap();
        let expiration = (low_and_expiration.into() / SHIFT_128).try_into().unwrap();

        let high = (high_and_nonce.into() & MASK_128).try_into().unwrap();
        let nonce = (high_and_nonce.into() / SHIFT_128).try_into().unwrap();

        let amount = u256 { low, high };
        Allowance { amount, expiration, nonce }
    }
}

pub impl AllowanceImpl of AllowanceTrait {
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
        let stored_expiration = if expiration == Self::BLOCK_TIMESTAMP_EXPIRATION {
            starknet::get_block_timestamp()
        } else {
            expiration
        };

        allowance.expiration = stored_expiration;
        allowance.amount = amount;
        self.write(allowance);
    }
}

#[cfg(test)]
mod tests {
    use super::{Allowance, AllowancePacking};
    use core::num::traits::Bounded;

    #[test]
    fn test_pack_and_unpack() {
        let test_cases = array![
            Allowance { amount: u256 { low: 0, high: 0 }, expiration: 0, nonce: 0 },
            Allowance { amount: Bounded::MAX, expiration: Bounded::MAX, nonce: Bounded::MAX },
            Allowance {
                amount: u256 { low: 123456789, high: 987654321 }, expiration: 555555, nonce: 999999,
            },
        ];

        for case in test_cases {
            let packed = AllowancePacking::pack(case);
            let unpacked = AllowancePacking::unpack(packed);
            assert_eq!(unpacked, case);
        }
    }

    #[test]
    #[fuzzer]
    fn test_fuzz_pack_and_unpack(amount: u256, expiration: u64, nonce: u64) {
        let allowance = Allowance { amount, expiration, nonce };
        let packed = AllowancePacking::pack(allowance);
        let mut unpacked = AllowancePacking::unpack(packed);
        assert_eq!(unpacked, allowance);
    }
}
