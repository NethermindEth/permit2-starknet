///
pub mod permit2 {
    pub mod interface;
    pub mod permit2;
}

///
pub mod libraries {
    pub mod allowance;
    pub mod mocks {
        pub mod erc20;
    }
}

///
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

pub mod unordered_nonces {
    pub mod interface;
    pub mod unordered_nonces;
}

