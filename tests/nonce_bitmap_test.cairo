use core::num::traits::{Bounded, Pow};
use permit2::components::unordered_nonces::UnorderedNoncesComponent::Error;
use permit2::interfaces::unordered_nonces::{
    IUnorderedNoncesSafeDispatcher, IUnorderedNoncesSafeDispatcherTrait,
};
use permit2::libraries::bitmap::{
    BIT_POSITION_OVERFLOW, BitmapPackingTrait, BitmapTrait, FeltBitmapPackingTraitImpl,
    FeltBitmapTraitImpl, INDEX_OUT_OF_RANGE, MASK_8, NONCE_SPACE_OVERFLOW, SHIFT_8,
};
use permit2::mocks::mock_permit2::{IMockPermit2SafeDispatcher, IMockPermit2SafeDispatcherTrait};
use starknet::get_contract_address;
use crate::setup::deploy_mock_permit2;


fn setup() -> IMockPermit2SafeDispatcher {
    let permit2_address = deploy_mock_permit2();
    IMockPermit2SafeDispatcher { contract_address: permit2_address }
}

fn setup2() -> IUnorderedNoncesSafeDispatcher {
    let permit2_address = deploy_mock_permit2();
    IUnorderedNoncesSafeDispatcher { contract_address: permit2_address }
}

fn nonce_already_invalidated() -> Array<felt252> {
    array![Error::NONCE_ALREADY_INVALIDATED]
}

fn nonce_space_overflow() -> Array<felt252> {
    array![NONCE_SPACE_OVERFLOW]
}

fn bit_position_overflow() -> Array<felt252> {
    array![BIT_POSITION_OVERFLOW]
}

fn index_out_of_range() -> Array<felt252> {
    array![INDEX_OUT_OF_RANGE]
}

#[test]
#[feature("safe_dispatcher")]
fn test_low_nonces() {
    let p2 = setup();
    let this = get_contract_address();

    assert(p2.use_unordered_nonce(this, 5).is_ok(), 'Nonce 5 should not fail');
    assert(p2.use_unordered_nonce(this, 0).is_ok(), 'Nonce 0 should not fail');
    assert(p2.use_unordered_nonce(this, 1).is_ok(), 'Nonce 1 should not fail');

    assert_eq!(p2.use_unordered_nonce(this, 5).unwrap_err(), nonce_already_invalidated());
    assert_eq!(p2.use_unordered_nonce(this, 0).unwrap_err(), nonce_already_invalidated());
    assert_eq!(p2.use_unordered_nonce(this, 1).unwrap_err(), nonce_already_invalidated());

    assert(p2.use_unordered_nonce(this, 4).is_ok(), 'Nonce 4 should not fail');
}

#[test]
#[feature("safe_dispatcher")]
fn test_bit_position_boundary() {
    let p2 = setup();
    let this = get_contract_address();

    assert(p2.use_unordered_nonce(this, 249).is_ok(), 'Nonce 249 should not fail');
    assert(p2.use_unordered_nonce(this, 250).is_ok(), 'Nonce 250 should not fail');
    assert_eq!(p2.use_unordered_nonce(this, 251).unwrap_err(), bit_position_overflow());

    assert_eq!(p2.use_unordered_nonce(this, 249).unwrap_err(), nonce_already_invalidated());
    assert_eq!(p2.use_unordered_nonce(this, 250).unwrap_err(), nonce_already_invalidated());
}

fn make_nonce(bit_pos: u8, nonce_space: u256) -> felt252 {
    BitmapPackingTrait::pack_nonce(nonce_space.try_into().unwrap(), bit_pos)
}

#[test]
#[feature("safe_dispatcher")]
fn test_high_nonces() {
    let p2 = setup();
    let this = get_contract_address();

    let nonce1 = make_nonce(250, 2_u256.pow(243) - 1);
    let nonce2 = make_nonce(250, 2_u256.pow(243) - 2);
    let nonce3 = make_nonce(249, 2_u256.pow(243) - 1);
    let nonce4 = make_nonce(249, 2_u256.pow(243) - 2);

    assert(p2.use_unordered_nonce(this, nonce1).is_ok(), 'nonce1 should not fail');
    assert(p2.use_unordered_nonce(this, nonce2).is_ok(), 'nonce2 should not fail');
    assert(p2.use_unordered_nonce(this, nonce3).is_ok(), 'nonce3 should not fail');
    assert(p2.use_unordered_nonce(this, nonce4).is_ok(), 'nonce4 should not fail');

    let nonce5: felt252 = (250 + 2_u256.pow(243) * 0x100)
        .try_into()
        .expect('nonce5 should fit in felt252');
    let nonce6: felt252 = (251 + (2_u256.pow(243) - 1) * 0x100)
        .try_into()
        .expect('nonce5 should fit in felt252');
    assert_eq!(p2.use_unordered_nonce(this, nonce5).unwrap_err(), nonce_space_overflow());
    assert_eq!(p2.use_unordered_nonce(this, nonce6).unwrap_err(), bit_position_overflow());
}

#[test]
#[feature("safe_dispatcher")]
fn test_invalidate_full_nonce_space() {
    let p2 = setup2();
    let this = get_contract_address();
    let nonce_space = 0;
    let mask: felt252 = (2_u256.pow(251) - 1).try_into().expect('mask should fit in felt252');

    assert(
        p2.invalidate_unordered_nonces(nonce_space, mask).is_ok(), 'Invalidation should succeed',
    );

    let p2 = IMockPermit2SafeDispatcher { contract_address: p2.contract_address };
    assert_eq!(p2.use_unordered_nonce(this, 0).unwrap_err(), nonce_already_invalidated());
    assert_eq!(p2.use_unordered_nonce(this, 1).unwrap_err(), nonce_already_invalidated());
    assert_eq!(p2.use_unordered_nonce(this, 249).unwrap_err(), nonce_already_invalidated());
    assert_eq!(p2.use_unordered_nonce(this, 250).unwrap_err(), nonce_already_invalidated());
}

#[test]
#[feature("safe_dispatcher")]
fn test_invalidate_nonzero_nonce_space() {
    let p2 = setup2();
    let this = get_contract_address();
    let nonce_space = 1;
    let mask: felt252 = (2_u256.pow(251) - 1).try_into().expect('mask should fit in felt252');

    assert(
        p2.invalidate_unordered_nonces(nonce_space, mask).is_ok(), 'Invalidation should succeed',
    );

    let n1 = 0 + (1 * SHIFT_8);
    let n2 = 1 + (1 * SHIFT_8);
    let n3 = 249 + (1 * SHIFT_8);
    let n4 = 250 + (1 * 1 * 1 * 1 * 1 * 1 * 1 * 1 * SHIFT_8);

    let p2 = IMockPermit2SafeDispatcher { contract_address: p2.contract_address };
    assert_eq!(
        p2.use_unordered_nonce(this, n1.try_into().unwrap()).unwrap_err(),
        nonce_already_invalidated(),
    );
    assert_eq!(
        p2.use_unordered_nonce(this, n2.try_into().unwrap()).unwrap_err(),
        nonce_already_invalidated(),
    );
    assert_eq!(
        p2.use_unordered_nonce(this, n3.try_into().unwrap()).unwrap_err(),
        nonce_already_invalidated(),
    );
    assert_eq!(
        p2.use_unordered_nonce(this, n4.try_into().unwrap()).unwrap_err(),
        nonce_already_invalidated(),
    );
}


#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn test_using_nonce_twice_fails(nonce: felt252) {
    let p2 = setup();
    let this = get_contract_address();

    assert(p2.use_unordered_nonce(this, 19).is_ok(), 'Nonce should not fail');
    assert_eq!(p2.use_unordered_nonce(this, 19).unwrap_err(), nonce_already_invalidated());
}

#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn test_use_two_random_nonces(mut first: felt252, mut second: felt252) {
    let p2 = setup();
    let this = get_contract_address();

    // A nonce's nonce space & bit position (bitmaps) are constrained, this limits them to only
    // valid bounds
    let nonce_u256_1: u256 = first.into();
    let nonce_u256_2: u256 = first.into();
    let nonce_space_1 = (nonce_u256_1 / SHIFT_8) % (2_u256.pow(243));
    let nonce_space_2 = (nonce_u256_2 / SHIFT_8) % (2_u256.pow(243));
    let bit_pos_1 = (nonce_u256_1 & MASK_8) % 251;
    let bit_pos_2 = (nonce_u256_2 & MASK_8) % 251;

    first = ((nonce_space_1 * SHIFT_8) + bit_pos_1).try_into().unwrap();
    second = ((nonce_space_2 * SHIFT_8) + bit_pos_2).try_into().unwrap();

    assert(p2.use_unordered_nonce(this, first).is_ok(), 'First nonce should not fail');
    if (first == second) {
        assert_eq!(p2.use_unordered_nonce(this, second).unwrap_err(), nonce_already_invalidated());
    } else {
        assert(p2.use_unordered_nonce(this, second).is_ok(), 'Second nonce should not fail');
    }
}

#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn test_invalidate_nonces_randomly(mut nonce_space: felt252, mut mask: felt252) {
    let _p2 = setup();
    let p2 = IUnorderedNoncesSafeDispatcher { contract_address: _p2.contract_address };
    let this = get_contract_address();

    // A nonce's nonce space & bit position (bitmaps) are constrained, this limits them to only
    // valid bounds
    let nonce_u256: u256 = nonce_space.into();

    mask = (mask.into() % (2_u256.pow(251))).try_into().expect('mask should fit in felt252');
    nonce_space = (nonce_u256 % (2_u256.pow(243)) * SHIFT_8 + mask.into() % 251)
        .try_into()
        .expect('nonce_space shd fit in felt252');

    assert(
        p2.invalidate_unordered_nonces(nonce_space, mask).is_ok(), 'Invalidation should succeed',
    );
    assert_eq!(mask, p2.nonce_bitmap(this, nonce_space).unwrap());
}

#[test]
#[fuzzer]
#[feature("safe_dispatcher")]
fn test_invalidate_two_nonces_randomly(
    mut nonce_space: felt252, mut start_bitmap: felt252, mut mask: felt252,
) {
    let _p2 = setup();
    let p2 = IUnorderedNoncesSafeDispatcher { contract_address: _p2.contract_address };
    let this = get_contract_address();

    // A nonce's nonce space & bit position (bitmaps) are constrained, this limits them to only
    // valid bounds
    let nonce_u256: u256 = nonce_space.into();

    mask = (mask.into() % (2_u256.pow(251))).try_into().expect('mask should fit in felt252');
    start_bitmap = (start_bitmap.into() % (2_u256.pow(251)))
        .try_into()
        .expect('bitmap should fit in felt252');
    nonce_space = (nonce_u256 % (2_u256.pow(243)) * SHIFT_8 + mask.into() % 251)
        .try_into()
        .expect('nonce_space shd fit in felt252');
    assert(
        p2.invalidate_unordered_nonces(nonce_space, start_bitmap).is_ok(),
        'Invalidation should succeed',
    );
    assert_eq!(start_bitmap, p2.nonce_bitmap(this, nonce_space).unwrap());

    let final_bitmap: u256 = mask.into() | start_bitmap.into();
    assert(
        p2.invalidate_unordered_nonces(nonce_space, mask).is_ok(),
        'Invldtion should
      succeed2',
    );
    let saved_bitmap = p2.nonce_bitmap(this, nonce_space).unwrap();
    assert_eq!(final_bitmap, saved_bitmap.into(), "Final bitmap should match");
    assert(p2.invalidate_unordered_nonces(nonce_space, mask).is_ok(), 'Invalidation shd succeed2');
    assert_eq!(
        final_bitmap,
        p2.nonce_bitmap(this, nonce_space).unwrap().into(),
        "Bitmap shd not change now",
    );
}

