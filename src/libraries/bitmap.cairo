use core::num::traits::{Pow, Zero};

const MASK_8: u256 = 0xFF;
const SHIFT_8: u256 = 0x100000000;


/// The `BitmapTrait` trait provides an interface for managing a bitmap representation
/// of nonces. It allows for the creation of a new bitmap, setting and unsetting bits
/// at specific indices, and retrieving the value of a bit at a given index.
pub trait BitmapTrait<T> {
    fn new() -> T;
    fn get(bitmap: T, index: usize) -> bool;
    fn set(ref bitmap: T, index: usize);
    fn unset(ref bitmap: T, index: usize);
}

/// The `BitmapPackingTrait` trait provides an interface for packing and unpacking
/// nonces into a bitmap representation. It allows for extracting the nonce space
/// and bit position from a nonce, and packing a nonce space and bit position back
pub trait BitmapPackingTrait<T> {
    fn unpack_nonce(nonce: T) -> (T, u8);
    fn pack_nonce(nonce_space: T, bit_pos: u8) -> T;
}

/// Bitmap implementation for felt252.
pub impl FeltBitmapTraitImpl of BitmapTrait<felt252> {
    fn new() -> felt252 {
        0
    }

    fn get(bitmap: felt252, index: usize) -> bool {
        assert(index < 252, 'Index out of range');
        (bitmap.into() & 2_u256.pow(index)).is_non_zero()
    }

    fn set(ref bitmap: felt252, index: usize) {
        assert(index < 252, 'Index out of range');
        bitmap = (bitmap.into() | 2_u256.pow(index)).try_into().unwrap();
    }

    fn unset(ref bitmap: felt252, index: usize) {
        assert(index < 252, 'Index out of range');
        bitmap = (bitmap.into() & (~2_u256.pow(index))).try_into().unwrap();
    }
}

/// Bitmap packing implementation for felt252.
pub impl FeltBitmapPackingTraitImpl of BitmapPackingTrait<felt252> {
    fn pack_nonce(nonce_space: felt252, bit_pos: u8) -> felt252 {
        let nonce_space_u256: u256 = nonce_space.into();
        ((nonce_space_u256 * SHIFT_8) + bit_pos.into())
            .try_into()
            .expect('pack_nonce: felt252 overflow')
    }

    fn unpack_nonce(nonce: felt252) -> (felt252, u8) {
        let nonce_u256: u256 = nonce.into();
        let bit_pos: u8 = (nonce_u256 & MASK_8).try_into().unwrap();
        let nonce_space = (nonce_u256 / SHIFT_8).try_into().unwrap();
        (nonce_space, bit_pos)
    }
}

