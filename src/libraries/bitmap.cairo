use core::num::traits::{Pow, Zero};

/// Constants
pub const MASK_8: u256 = 0xFF;
pub const SHIFT_8: u256 = 0b100000000;

/// Errors
pub const INDEX_OUT_OF_RANGE: felt252 = 'Index out of range';
pub const NONCE_SPACE_OVERFLOW: felt252 = 'Nonce space overflow';
pub const BIT_POSITION_OVERFLOW: felt252 = 'Bit position overflow';
// 2_u256.pow(243) - 1
pub const MAX_NONCE_SPACE: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
// 2_u256.pow(251) - 1
pub const MAX_BIT_MAP: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

/// The `BitmapTrait` trait provides an interface for managing a bitmap representation
/// of nonces. It allows for the creation of a new bitmap, setting and unsetting bits
/// at specific indices, and retrieving the value of a bit at a given index.
pub trait BitmapTrait<T> {
    fn new() -> T;
    fn get(bitmap: T, index: u8) -> bool;
    fn set(ref bitmap: T, index: u8);
    fn unset(ref bitmap: T, index: u8);
}

/// Bitmap implementation for felt252.
/// Supports up to 251 bit.
pub impl FeltBitmapTraitImpl of BitmapTrait<felt252> {
    fn new() -> felt252 {
        0
    }

    fn get(bitmap: felt252, index: u8) -> bool {
        assert(index < 251, INDEX_OUT_OF_RANGE);
        (bitmap.into() & 2_u256.pow(index.into())).is_non_zero()
    }

    fn set(ref bitmap: felt252, index: u8) {
        assert(index < 251, INDEX_OUT_OF_RANGE);
        bitmap = (bitmap.into() | 2_u256.pow(index.into())).try_into().unwrap();
    }

    fn unset(ref bitmap: felt252, index: u8) {
        assert(index < 251, INDEX_OUT_OF_RANGE);
        bitmap = (bitmap.into() & (~2_u256.pow(index.into()))).try_into().expect('asdf2');
    }
}

#[cfg(test)]
mod felt_bitmap_test {
    use super::BitmapTrait;

    #[test]
    #[fuzzer]
    fn test_should_set_arbitrary_index(mut index: u8) {
        index %= 251;
        let mut bitmap: felt252 = BitmapTrait::new();
        BitmapTrait::set(ref bitmap, index.into());
        assert!(BitmapTrait::get(bitmap, index.into()), "Bit not set");
    }

    #[test]
    #[fuzzer]
    fn test_should_set_then_unset_arbitrary_index(mut index: u8) {
        index %= 251;
        let mut bitmap: felt252 = BitmapTrait::new();
        BitmapTrait::set(ref bitmap, index.into());
        assert!(BitmapTrait::get(bitmap, index.into()), "Bit not set");

        BitmapTrait::unset(ref bitmap, index.into());
        assert!(!BitmapTrait::get(bitmap, index.into()), "Bit not unset");
    }
}

/// The `BitmapPackingTrait` trait provides an interface for packing and unpacking
/// nonces into a bitmap representation. It allows for extracting the nonce space
/// and bit position from a nonce, and packing a nonce space and bit position back
///
/// Packed Nonce Representation (251 bits):
/// +----------------------------------------------------------------------------------+
/// |                     8 bits for nonce position   |    243 bits for nonce space
/// |  Bit Index:     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | ... | 250 |
/// |  Packed Nonce:  | 0 | 1 |  0 | 0 | 0 | ...  | 0 | 0 | 1 | 1 | 1 |
/// +----------------------------------------------------------------------------------+
///
/// Valid nonce spaces are: [0, 2^243), i.e [0,1,2,...,2^243 - 1]
///
/// Valid indices are: [0, 251), i.e [0,1,2,...,250]
pub trait BitmapPackingTrait<T> {
    fn unpack_nonce(nonce: T) -> (T, u8);
    fn pack_nonce(nonce_space: T, index: u8) -> T;
}

pub impl FeltBitmapPackingTraitImpl of BitmapPackingTrait<felt252> {
    fn pack_nonce(nonce_space: felt252, index: u8) -> felt252 {
        assert(index < 251, BIT_POSITION_OVERFLOW);
        assert(nonce_space.into() <= MAX_NONCE_SPACE, NONCE_SPACE_OVERFLOW);

        ((nonce_space.into() * SHIFT_8) + index.into()).try_into().unwrap()
    }

    fn unpack_nonce(nonce: felt252) -> (felt252, u8) {
        let nonce: u256 = nonce.into();
        let index = nonce & MASK_8;
        let nonce_space = nonce / SHIFT_8;

        assert(index < 251, BIT_POSITION_OVERFLOW);
        assert(nonce_space <= MAX_NONCE_SPACE, NONCE_SPACE_OVERFLOW);

        (nonce_space.try_into().unwrap(), index.try_into().unwrap())
    }
}

