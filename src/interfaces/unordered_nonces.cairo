use starknet::ContractAddress;

#[starknet::interface]
pub trait IUnorderedNonces<TState> {
    /// Read ///

    /// @notice A map from token owner address and a caller specified nonce_space to a bitmap. Used
    /// to set bits in the bitmap to prevent against signature replay protection
    /// @dev Uses unordered nonces so that permit messages do not need to be spent in a certain
    /// order
    /// @dev The mapping is indexed first by the token owner, then by a nonce_space specified in
    /// the nonce
    /// @dev It returns a felt252 bitmap
    /// @dev The nonce_space, or wordPosition is capped at
    /// type(uint244).max
    fn nonce_bitmap(self: @TState, owner: ContractAddress, nonce_space: felt252) -> felt252;

    /// Determines if nonce is usable.
    ///
    /// Parameters:
    ///
    /// - 'owner': address to query nonce for.
    /// - 'nonce': nonce to determine if it is usable or not.
    ///
    /// Returns 'true' if the nonce is usable for the given nonce space.
    fn is_nonce_usable(self: @TState, owner: ContractAddress, nonce: felt252) -> bool;

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
    fn invalidate_unordered_nonces(ref self: TState, nonce_space: felt252, mask: felt252);
}

