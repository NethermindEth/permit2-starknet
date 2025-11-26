#[starknet::component]
pub mod UnorderedNoncesComponent {
    use crate::interfaces::unordered_nonces::IUnorderedNonces;
    use crate::libraries::bitmap::{
        BIT_POSITION_OVERFLOW, BitmapPackingTrait, BitmapTrait, MAX_BIT_MAP,
    };
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};

    /// ERRORS ///
    pub mod Error {
        pub const NONCE_ALREADY_INVALIDATED: felt252 = 'Nonce already invalidated';
    }


    /// STORAGE ///
    #[storage]
    pub struct Storage {
        pub nonces_bitmap: Map<(ContractAddress, felt252), felt252>,
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
            let (nonce_space, bit_pos) = BitmapPackingTrait::unpack_nonce(nonce);
            let bitmap = self.nonces_bitmap.entry((owner, nonce_space)).read();
            !BitmapTrait::get(bitmap, bit_pos.into())
        }

        /// Write ///

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
            let owner = get_caller_address();
            let bitmap_storage = self.nonces_bitmap.entry((owner, nonce_space));
            let bitmap = bitmap_storage.read();
            let mask_u256: u256 = mask.into();

            assert(mask_u256 <= MAX_BIT_MAP, BIT_POSITION_OVERFLOW);

            let new_bitmap = (bitmap.into() | mask_u256).try_into().unwrap();
            bitmap_storage.write(new_bitmap);

            self.emit(UnorderedNonceInvalidation { owner, nonce_space, mask });
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
/// The `UnorderedNoncesComponent` is designed for concurrent usage of nonces.
///
/// Nonces are represented in this component as a mapping from an owner and nonce space to a bitmap
/// of 251 nonces. Each nonce space corresponds to a unique identifier, and the bitmap efficiently
/// tracks the status of each nonce within that space.
///
/// Each bit in the bitmap represents a nonce, where a value of 1 indicates that the nonce is
/// invalidated, and a value of 0 indicates that it is usable.
///
/// Note: Even though this bitmap is represented as a `felt252`, it can only represent 251 nonces
/// (bits). This is because the maximum value of a felt252 is less than the maximum value of an
/// unsigned integer of size 252 (max u252 =2^252 - 1, max felt252 = 2^251 + 17 * 2^192).
///
/// Each nonce is identified by its `nonce space` and `bit position`. For more efficient
/// serialization, information can be compactly packed into a single felt as follows:
///   1. The lower 8 bits (index) → Represents the index [0 to 250].
///   2. The remaining 244 bits     → Represents the unique nonce space [0, ..., 2^243 - 1].
///
/// In storage, the nonce is a `Map<(ContractAddress, felt252), felt252>`. This Map maps (owner,
/// nonce_space) to a bitmap representing 251 nonces, explained as follows:
///
/// Example nonce: 904625697166532776746648320380374280103671755200316906558262375061821325323
///
/// Nonce as binary: 0b01000...0001011 (251 bits)
///
/// Packed Nonce Representation (binary):
///         | (First 8 bits)|     (Last 243 bits )          |
///         <-bit position->|<---------nonce space---------->
/// Packed: |1|1|0|1|0|0|0|0|0|0|0|0|0|0|...| 0 | 0 | 1 | 0 |
/// Index:  |0|1|2|3|4|5|6|7|8|    ...      |247|248|249|250|
///
/// In this example, the upper 243 bits represent the nonce space (0b0100...0000). The
/// lower 8 bits (0b00001011) mean that the nonces 0, 1, and 3 in this nonce space are
/// invalidated (set to 1). This nonce would be stored as Map(owner, 0b010...000) = 0b1011.
///
/// The packed nonce format allows for the representation of up to 251 nonces in a single felt252
/// slot, enabling the invalidation of multiple nonces at once. This is particularly useful for
/// batch operations where several nonces need to be revoked simultaneously.
///
/// Nonce invalidation:
///
/// Bit Index:     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | ... | 250 |
/// Nonce Bitmap:  | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | ... | 0 |
/// Mask:          | 1 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | ... | 1 |
/// Bitwise OR  ____________________________________________________
///
/// Result:        | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 0 | ... | 1 |
///
/// In this example, nonces 2, 4, 5 and 251 are invalidated (set to 1); nonces 0, 1, and 3 were
/// already invalidated.


