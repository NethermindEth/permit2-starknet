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

