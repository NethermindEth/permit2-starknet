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
    use permit2::interfaces::unordered_nonces::IUnorderedNonces;
    use permit2::libraries::bitmap::{BitmapPackingTrait, BitmapTrait};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    /// ERRORS ///

    pub mod Error {
        pub const NONCE_ALREADY_INVALIDATED: felt252 = 'Nonce already invalidated';
    }


    /// STORAGE ///

    #[storage]
    pub struct Storage {
        nonces_bitmap: Map<(ContractAddress, felt252), felt252>,
    }

    /// EVENTS ///

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UnorderedNonceInvalidation: UnorderedNonceInvalidation,
        NonceInvalidated: NonceInvalidated,
    }

    /// Emitted when a single nonce is invalidated.
    #[derive(Drop, starknet::Event)]
    pub struct NonceInvalidated {
        #[key]
        pub owner: ContractAddress,
        pub nonce: felt252,
    }

    /// Emitted when one or multiple nonces are invalidated.
    #[derive(Drop, starknet::Event)]
    pub struct UnorderedNonceInvalidation {
        #[key]
        pub owner: ContractAddress,
        pub nonce_space: felt252,
        pub mask: felt252,
    }


    #[embeddable_as(UnorderedNoncesImpl)]
    pub impl UnorderedNonces<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IUnorderedNonces<ComponentState<TContractState>> {
        /// Read ///

        /// Returns `felt252` representing the nonce bitmap in the given `nonce_space`.
        fn nonce_bitmap(
            self: @ComponentState<TContractState>, owner: ContractAddress, nonce_space: felt252,
        ) -> felt252 {
            self.nonces_bitmap.entry((owner, nonce_space)).read()
        }


        fn is_nonce_usable(
            self: @ComponentState<TContractState>, owner: ContractAddress, nonce: felt252,
        ) -> bool {
            let (nonce_space, bit_pos) = BitmapPackingTrait::unpack_nonce(nonce);
            let bitmap = self.nonces_bitmap.entry((owner, nonce_space)).read();
            !BitmapTrait::get(bitmap, bit_pos.into())
        }

        /// Write ///

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
            let (nonce_space, bit_pos) = BitmapPackingTrait::unpack_nonce(nonce);
            let bitmap_storage = self.nonces_bitmap.entry((owner, nonce_space));
            let mut bitmap = bitmap_storage.read();

            assert(!BitmapTrait::get(bitmap, bit_pos.into()), Error::NONCE_ALREADY_INVALIDATED);

            BitmapTrait::set(ref bitmap, bit_pos.into());
            bitmap_storage.write(bitmap);

            self.emit(NonceInvalidated { owner, nonce });
        }
    }
}

