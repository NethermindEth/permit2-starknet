pub mod libraries {
    pub mod allowance;
    pub mod bitmap;
    pub mod permit2_lib;
    pub mod utils;
}
pub mod mocks {
    pub mod mock_account;
    pub mod mock_erc20;
    pub mod mock_erc20_permit;
    pub mod mock_witness;
}

pub mod components {
    pub mod allowance_transfer;
    pub mod signature_transfer;
    pub mod unordered_nonces;
}

pub mod interface;
pub mod permit2;
pub mod snip12_utils {
    pub mod permits;
}

pub mod interfaces {
    pub mod allowance_transfer;
    pub mod signature_transfer;
    pub mod unordered_nonces;
}

