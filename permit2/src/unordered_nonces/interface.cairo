use core::num::traits::{Pow, Zero};
use starknet::ContractAddress;

/// EVENTS ///
pub mod events {
    use starknet::ContractAddress;

    #[event]
    #[derive(starknet::Event, Drop)]
    pub enum UnorderedNonceEvent {
        UnorderedNonceInvalidation: UnorderedNonceInvalidation,
        NonceInvalidated: NonceInvalidated,
    }

    /// Emitted when one or multiple nonces are invalidated.
    #[derive(Drop, starknet::Event)]
    pub struct UnorderedNonceInvalidation {
        pub owner: ContractAddress,
        pub nonce_space: felt252,
        pub mask: felt252,
    }

    /// Emitted when a single nonce is invalidated.
    #[derive(Drop, starknet::Event)]
    pub struct NonceInvalidated {
        pub owner: ContractAddress,
        pub nonce: felt252,
    }
}

/// ERRORS ///
pub mod errors {
    pub const NONCE_ALREADY_INVALIDATED: felt252 = 'Nonce already invalidated';
}


/// INTERFACE ///

#[starknet::interface]
pub trait IUnorderedNonces<TState> {
    /// Read ///

    fn is_nonce_usable(self: @TState, owner: ContractAddress, nonce: felt252) -> bool;

    fn get_nonce_space(self: @TState, owner: ContractAddress, nonce_space: felt252) -> felt252;

    /// From ISignatureTransfer.sol

    /// @notice A map from token owner address and a caller specified word index to a bitmap. Used
    /// to set bits in the bitmap to prevent against signature replay protection @dev Uses unordered
    /// nonces so that permit messages do not need to be spent in a certain order @dev The mapping
    /// is indexed first by the token owner, then by an index specified in the nonce @dev It returns
    /// a felt252 bitmap @dev The index, or wordPosition is capped at type(uint244).max
    /// NOTE: This function appears to be the same as `get_nonce_space`; this one is defined here:
    /// https://github.com/Uniswap/permit2/blob/cc56ad0f3439c502c246fc5cfcc3db92bb8b7219/src/interfaces/ISignatureTransfer.sol#L65
    /// - unsure which to use at this time
    fn nonce_bitmap(self: @TState, owner: ContractAddress, nonce_space: felt252) -> felt252;

    /// Write ///

    /// @notice Invalidates the bits specified in mask for the bitmap at the word position
    /// @dev The wordPos is maxed at type(uint248).max
    /// @param wordPos A number to index the nonceBitmap at
    /// @param mask A bitmap masked against msg.sender's current bitmap at the word position
    fn invalidate_unordered_nonces(ref self: TState, nonce_space: felt252, mask: felt252);
}

/// The `BitmapTrait` trait provides an interface for managing a bitmap representation
/// of nonces. It allows for the creation of a new bitmap, setting and unsetting bits
/// at specific indices, and retrieving the value of a bit at a given index.
pub trait BitmapTrait<T> {
    fn new() -> T;
    fn get(bitmap: T, index: usize) -> bool;
    fn set(ref bitmap: T, index: usize);
    fn unset(ref bitmap: T, index: usize);
}

/// Bitmap implementation for felt252.
impl FeltBitmapTraitImpl of BitmapTrait<felt252> {
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

