// From:
// https://github.com/starkware-libs/cairo/blob/17190043094456e70c764a1463f7a16a56cdb971/crates/cairo-lang-starknet/cairo_level_tests/keccak.cairo#L2
// Dynamically computes a selector from a ByteArray at runtime.
// Runtime version of the `selector!` macro.
pub fn selector(input: ByteArray) -> felt252 {
    let value = core::keccak::compute_keccak_byte_array(@input);
    u256 {
        low: core::integer::u128_byte_reverse(value.high),
        high: core::integer::u128_byte_reverse(value.low) & 0x3ffffffffffffffffffffffffffffff,
    }
        .try_into()
        .unwrap()
}

#[cfg(test)]
pub mod selector_tests {
    use super::selector;

    fn test_keccak_byte_array() {
        assert_eq!(selector(""), selector!(""));
        assert_eq!(selector("0123456789abedef"), selector!("0123456789abedef"));
        assert_eq!(selector("hello-world"), selector!("hello-world"));
    }

    fn test_keccak_byte_array_vars() {
        let a: ByteArray = "";
        let b: ByteArray = "0123456789abedef";
        let c: ByteArray = "hello-world";
        assert_eq!(selector(a), selector!(""));
        assert_eq!(selector(b), selector!("0123456789abedef"));
        assert_eq!(selector(c), selector!("hello-world"));
    }
}

