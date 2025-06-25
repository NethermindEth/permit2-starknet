use core::num::traits::{Pow, Zero};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IUnorderedNonces<TContractState> {
    fn invalidate_unordered_nonces(ref self: TContractState, nonce_space: felt252, mask: felt252);
    fn is_nonce_usable(self: @TContractState, owner: ContractAddress, nonce: felt252) -> bool;
    fn get_nonce_space(
        self: @TContractState, owner: ContractAddress, nonce_space: felt252,
    ) -> felt252;
}

/// The `BitmapTrait` trait provides an interface for managing a bitmap representation
/// of nonces. It allows for the creation of a new bitmap, setting and unsetting bits
/// at specific indices, and retrieving the value of a bit at a given index.
pub trait BitmapTrait<T> {
    fn new() -> T;
    fn set(ref bitmap: T, index: usize);
    fn unset(ref bitmap: T, index: usize);
    fn get(bitmap: T, index: usize) -> bool;
}

/// Bitmap implementation for felt252.
impl FeltBitmapTraitImpl of BitmapTrait<felt252> {
    fn new() -> felt252 {
        0
    }

    fn set(ref bitmap: felt252, index: usize) {
        assert(index < 252, 'Index out of range');
        bitmap = (bitmap.into() | 2_u256.pow(index)).try_into().unwrap();
    }

    fn unset(ref bitmap: felt252, index: usize) {
        assert(index < 252, 'Index out of range');
        bitmap = (bitmap.into() & (~2_u256.pow(index))).try_into().unwrap();
    }

    fn get(bitmap: felt252, index: usize) -> bool {
        assert(index < 252, 'Index out of range');
        (bitmap.into() & 2_u256.pow(index)).is_non_zero()
    }
}

//! The `UnorderedNoncesComponent` is designed for concurrent usage of nonces.
//!
//! Nonces are represented in this component as a mapping from an owner and nonce space to a bitmap
//! of 252 nonces. Each nonce space corresponds to a unique identifier, and the bitmap efficiently
//! tracks the status of each nonce within that space. Each bit in the bitmap represents a nonce,
//! where a value of 1 indicates that the nonce is invalidated, and a value of 0 indicates that it
//! is usable.
//!
//! Each nonce is identified by its `nonce space` and `nonce position`. For more efficient
//! serialization, information can be compactly packed into a single felt as follows:
//!   1. The lower 8 bits (bit_pos)       → Represents the index (0 to 251).
//!   2. The remaining 244 bits          → Represents the unique nonce space.
//!
//! For example, a single packed nonce looks like this when represented in felt:
//!
//! Packed Nonce Representation (252 bits):
//! +----------------------------------------------------------------------------------+
//! |                     8 bits for nonce position   |    244 bits for nonce space
//! |  Bit Index:     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | ... | 251 |
//! |  Packed Nonce:  | 0 | 1 |  0 | 0 | 0 |... | 0 | 0 | 1 | 1 | 1 |
//!
//! In storage, the nonce is a `Map<(ContractAddress, felt252), felt252>` mapping (owner,
//! nonce_space) to a bitmap representing 252 nonces, explained as follows:
//!
//! Nonce bitmap representation:
//!
//! Bit Index:     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | ... | 251 |
//! Nonce Bitmap:  | 0 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | ... | 0 |
//!
//! In this example, nonces 2, 4, and 5 are invalidated (set to 1) while others remain usable (set
//! to 0).
//!
//! The packed nonce format allows for the representation of up to 252 nonces in a single felt252
//! slot, enabling the invalidation of multiple nonces at once. This is particularly useful for
//! batch operations where several nonces need to be revoked simultaneously.
//!
//! Nonce invalidation:
//!
//! Bit Index:     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | ... | 251 |
//! Nonce Bitmap:  | 0 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | ... | 0 |
//! Mask:          | 0 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | ... | 1 |
//! Bitwise OR  ____________________________________________________
//!
//! Result:        | 0 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | ... | 1 |
//!
//! In this example, nonces 1, 3, and 251 are invalidated (set to 1).
//!
//! Features:
//!
//! - **Revoking Nonces**: An external function to invalidate single or multiple nonces in a nonce
//! space and an internal function that consumes a nonce represented in compact (nonce_space,
//! bitpos)
//! format. If a nonce is already consumed, it panics.
//!
//! - **Querying availability of nonces**: Functions to determine if a given nonce is usable or not.

#[starknet::component]
pub mod UnorderedNoncesComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::BitmapTrait;

    const MASK_8: u256 = 0xFF;
    const SHIFT_8: u256 = 0x100000000;

    #[storage]
    pub struct Storage {
        nonces_bitmap: Map<(ContractAddress, felt252), felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UnorderedNonceInvalidation: UnorderedNonceInvalidation,
        NonceInvalidated: NonceInvalidated,
    }

    /// Emitted when a single nonce is invalidated.
    #[derive(Drop, starknet::Event)]
    pub struct NonceInvalidated {
        pub owner: ContractAddress,
        pub nonce: felt252,
    }

    /// Emitted when one or multiple nonces are invalidated.
    #[derive(Drop, starknet::Event)]
    pub struct UnorderedNonceInvalidation {
        pub owner: ContractAddress,
        pub nonce_space: felt252,
        pub mask: felt252,
    }

    pub mod Errors {
        pub const NONCE_ALREADY_INVALIDATED: felt252 = 'Nonce already invalidated';
    }

    #[embeddable_as(UnorderedNoncesImpl)]
    pub impl UnorderedNonces<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of super::IUnorderedNonces<ComponentState<TContractState>> {
        /// Invalidates nonces in the given 'nonce_space' for the 'caller'. Nonces to invalidate are
        /// represented as a bitmask.
        ///
        /// For example:
        ///
        /// If the first 16 bits are set, it invalidates nonces [0, 16].
        ///
        /// Mask = 0xFFFF
        ///
        /// Max(felt252) to invalidate all nonces in the nonce_space at once.
        ///
        /// Parameters:
        ///
        /// - 'nonce_space': nonce_space from which to revoke nonces.
        /// - 'mask': mask that represents nonces to invalidate.
        fn invalidate_unordered_nonces(
            ref self: ComponentState<TContractState>, nonce_space: felt252, mask: felt252,
        ) {
            let caller = starknet::get_caller_address();
            let bitmap_storage = self.nonces_bitmap.entry((caller, nonce_space));
            let bitmap = bitmap_storage.read();
            let mask_u256: u256 = mask.into();
            let new_bitmap = (bitmap.into() | mask_u256).try_into().unwrap();
            bitmap_storage.write(new_bitmap);

            self.emit(UnorderedNonceInvalidation { owner: caller, nonce_space, mask });
        }

        /// Determines if nonce is usable.
        ///
        /// Parameters:
        ///
        /// - 'owner': address to query nonce for.
        /// - 'nonce': nonce to determine if it is usable or not.
        ///
        /// Returns 'true' if the nonce is usable for the given nonce space.
        fn is_nonce_usable(
            self: @ComponentState<TContractState>, owner: ContractAddress, nonce: felt252,
        ) -> bool {
            let (nonce_space, bit_pos) = bitmap_positions(nonce);
            let bitmap = self.nonces_bitmap.entry((owner, nonce_space)).read();
            !BitmapTrait::get(bitmap, bit_pos.into())
        }

        /// Returns `felt252` representing the nonce bitmap in the given `nonce_space`.
        fn get_nonce_space(
            self: @ComponentState<TContractState>, owner: ContractAddress, nonce_space: felt252,
        ) -> felt252 {
            self.nonces_bitmap.entry((owner, nonce_space)).read()
        }
    }

    /// Unpacks `felt252` into nonce space and bit position.
    pub fn bitmap_positions(nonce: felt252) -> (felt252, u8) {
        let nonce_u256: u256 = nonce.into();
        let bit_pos: u8 = (nonce_u256 & MASK_8).try_into().unwrap();
        let nonce_space = (nonce_u256 / SHIFT_8).try_into().unwrap();
        (nonce_space, bit_pos)
    }

    /// Packs the `nonce_space` and `bit_pos` into `felt252`
    pub fn pack_nonce(nonce_space: felt252, bit_pos: u8) -> felt252 {
        let nonce_space_u256: u256 = nonce_space.into();
        ((nonce_space_u256 * SHIFT_8) + bit_pos.into())
            .try_into()
            .expect('pack_nonce: felt252 overflow')
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Internal function that consumes a nonce by nonce space and bit position. Panics if the
        /// nonce is already used.
        ///
        /// Parameters:
        ///
        /// - 'owner': address to query nonce for.
        /// - 'nonce': nonce to determine if it is usable or not.
        fn _use_unordered_nonce(
            ref self: ComponentState<TContractState>, owner: ContractAddress, nonce: felt252,
        ) {
            let (nonce_space, bit_pos) = bitmap_positions(nonce);
            let bitmap_storage = self.nonces_bitmap.entry((owner, nonce_space));
            let mut bitmap = bitmap_storage.read();
            assert(!BitmapTrait::get(bitmap, bit_pos.into()), Errors::NONCE_ALREADY_INVALIDATED);
            BitmapTrait::set(ref bitmap, bit_pos.into());
            bitmap_storage.write(bitmap);
            self.emit(NonceInvalidated { owner, nonce });
        }
    }
}
