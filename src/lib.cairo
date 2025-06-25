pub mod libraries {
    pub mod allowance;
    pub mod unordered_nonces;
}

pub mod allowance_transfer {
    pub mod allowance_transfer;
    pub mod interface;
    pub mod snip12_utils;
}

pub mod signature_transfer {
    pub mod interface;
    pub mod signature_transfer;
    pub mod snip12_utils;
}

pub mod mocks {
    pub mod mock_account;
    pub mod mock_erc20;
    //pub mod mock_erc20_permit;
}

pub mod permit2;
