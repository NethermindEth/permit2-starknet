export const ABI = [
  {
    "type": "impl",
    "name": "Permit2",
    "interface_name": "permit2::interfaces::permit2::IPermit2"
  },
  {
    "type": "interface",
    "name": "permit2::interfaces::permit2::IPermit2",
    "items": [
      {
        "type": "function",
        "name": "DOMAIN_SEPARATOR",
        "inputs": [],
        "outputs": [
          {
            "type": "core::felt252"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "type": "impl",
    "name": "AllowedTransferImpl",
    "interface_name": "permit2::interfaces::allowance_transfer::IAllowanceTransfer"
  },
  {
    "type": "struct",
    "name": "core::integer::u256",
    "members": [
      {
        "name": "low",
        "type": "core::integer::u128"
      },
      {
        "name": "high",
        "type": "core::integer::u128"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::allowance_transfer::PermitDetails",
    "members": [
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "amount",
        "type": "core::integer::u256"
      },
      {
        "name": "expiration",
        "type": "core::integer::u64"
      },
      {
        "name": "nonce",
        "type": "core::integer::u64"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::allowance_transfer::PermitSingle",
    "members": [
      {
        "name": "details",
        "type": "permit2::interfaces::allowance_transfer::PermitDetails"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "sig_deadline",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "type": "struct",
    "name": "core::array::Span::<permit2::interfaces::allowance_transfer::PermitDetails>",
    "members": [
      {
        "name": "snapshot",
        "type": "@core::array::Array::<permit2::interfaces::allowance_transfer::PermitDetails>"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::allowance_transfer::PermitBatch",
    "members": [
      {
        "name": "details",
        "type": "core::array::Span::<permit2::interfaces::allowance_transfer::PermitDetails>"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "sig_deadline",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::allowance_transfer::AllowanceTransferDetails",
    "members": [
      {
        "name": "from",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "to",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "amount",
        "type": "core::integer::u256"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::allowance_transfer::TokenSpenderPair",
    "members": [
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress"
      }
    ]
  },
  {
    "type": "interface",
    "name": "permit2::interfaces::allowance_transfer::IAllowanceTransfer",
    "items": [
      {
        "type": "function",
        "name": "allowance",
        "inputs": [
          {
            "name": "user",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "spender",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "(core::integer::u256, core::integer::u64, core::integer::u64)"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "approve",
        "inputs": [
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "spender",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "amount",
            "type": "core::integer::u256"
          },
          {
            "name": "expiration",
            "type": "core::integer::u64"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "permit",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "permit",
            "type": "permit2::interfaces::allowance_transfer::PermitSingle"
          },
          {
            "name": "signature",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "permit_batch",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "permit",
            "type": "permit2::interfaces::allowance_transfer::PermitBatch"
          },
          {
            "name": "signature",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "transfer_from",
        "inputs": [
          {
            "name": "from",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "to",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "amount",
            "type": "core::integer::u256"
          },
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "batch_transfer_from",
        "inputs": [
          {
            "name": "transfer_details",
            "type": "core::array::Array::<permit2::interfaces::allowance_transfer::AllowanceTransferDetails>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "lockdown",
        "inputs": [
          {
            "name": "approvals",
            "type": "core::array::Array::<permit2::interfaces::allowance_transfer::TokenSpenderPair>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "invalidate_nonces",
        "inputs": [
          {
            "name": "token",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "spender",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "new_nonce",
            "type": "core::integer::u64"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      }
    ]
  },
  {
    "type": "impl",
    "name": "SignatureTransferImpl",
    "interface_name": "permit2::interfaces::signature_transfer::ISignatureTransfer"
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::signature_transfer::TokenPermissions",
    "members": [
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "amount",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::signature_transfer::PermitTransferFrom",
    "members": [
      {
        "name": "permitted",
        "type": "permit2::interfaces::signature_transfer::TokenPermissions"
      },
      {
        "name": "nonce",
        "type": "core::felt252"
      },
      {
        "name": "deadline",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::signature_transfer::SignatureTransferDetails",
    "members": [
      {
        "name": "to",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "name": "requested_amount",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "type": "struct",
    "name": "core::array::Span::<permit2::interfaces::signature_transfer::TokenPermissions>",
    "members": [
      {
        "name": "snapshot",
        "type": "@core::array::Array::<permit2::interfaces::signature_transfer::TokenPermissions>"
      }
    ]
  },
  {
    "type": "struct",
    "name": "permit2::interfaces::signature_transfer::PermitBatchTransferFrom",
    "members": [
      {
        "name": "permitted",
        "type": "core::array::Span::<permit2::interfaces::signature_transfer::TokenPermissions>"
      },
      {
        "name": "nonce",
        "type": "core::felt252"
      },
      {
        "name": "deadline",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "type": "struct",
    "name": "core::array::Span::<permit2::interfaces::signature_transfer::SignatureTransferDetails>",
    "members": [
      {
        "name": "snapshot",
        "type": "@core::array::Array::<permit2::interfaces::signature_transfer::SignatureTransferDetails>"
      }
    ]
  },
  {
    "type": "struct",
    "name": "core::byte_array::ByteArray",
    "members": [
      {
        "name": "data",
        "type": "core::array::Array::<core::bytes_31::bytes31>"
      },
      {
        "name": "pending_word",
        "type": "core::felt252"
      },
      {
        "name": "pending_word_len",
        "type": "core::integer::u32"
      }
    ]
  },
  {
    "type": "interface",
    "name": "permit2::interfaces::signature_transfer::ISignatureTransfer",
    "items": [
      {
        "type": "function",
        "name": "permit_transfer_from",
        "inputs": [
          {
            "name": "permit",
            "type": "permit2::interfaces::signature_transfer::PermitTransferFrom"
          },
          {
            "name": "transfer_details",
            "type": "permit2::interfaces::signature_transfer::SignatureTransferDetails"
          },
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "signature",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "permit_batch_transfer_from",
        "inputs": [
          {
            "name": "permit",
            "type": "permit2::interfaces::signature_transfer::PermitBatchTransferFrom"
          },
          {
            "name": "transfer_details",
            "type": "core::array::Span::<permit2::interfaces::signature_transfer::SignatureTransferDetails>"
          },
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "signature",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "permit_witness_transfer_from",
        "inputs": [
          {
            "name": "permit",
            "type": "permit2::interfaces::signature_transfer::PermitTransferFrom"
          },
          {
            "name": "transfer_details",
            "type": "permit2::interfaces::signature_transfer::SignatureTransferDetails"
          },
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "witness",
            "type": "core::felt252"
          },
          {
            "name": "witness_type_string",
            "type": "core::byte_array::ByteArray"
          },
          {
            "name": "signature",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "type": "function",
        "name": "permit_witness_batch_transfer_from",
        "inputs": [
          {
            "name": "permit",
            "type": "permit2::interfaces::signature_transfer::PermitBatchTransferFrom"
          },
          {
            "name": "transfer_details",
            "type": "core::array::Span::<permit2::interfaces::signature_transfer::SignatureTransferDetails>"
          },
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "witness",
            "type": "core::felt252"
          },
          {
            "name": "witness_type_string",
            "type": "core::byte_array::ByteArray"
          },
          {
            "name": "signature",
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      }
    ]
  },
  {
    "type": "impl",
    "name": "UnorderedNoncesImpl",
    "interface_name": "permit2::interfaces::unordered_nonces::IUnorderedNonces"
  },
  {
    "type": "enum",
    "name": "core::bool",
    "variants": [
      {
        "name": "False",
        "type": "()"
      },
      {
        "name": "True",
        "type": "()"
      }
    ]
  },
  {
    "type": "interface",
    "name": "permit2::interfaces::unordered_nonces::IUnorderedNonces",
    "items": [
      {
        "type": "function",
        "name": "nonce_bitmap",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "nonce_space",
            "type": "core::felt252"
          }
        ],
        "outputs": [
          {
            "type": "core::felt252"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "is_nonce_usable",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "nonce",
            "type": "core::felt252"
          }
        ],
        "outputs": [
          {
            "type": "core::bool"
          }
        ],
        "state_mutability": "view"
      },
      {
        "type": "function",
        "name": "invalidate_unordered_nonces",
        "inputs": [
          {
            "name": "nonce_space",
            "type": "core::felt252"
          },
          {
            "name": "mask",
            "type": "core::felt252"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::allowance_transfer::AllowanceTransferComponent::NonceInvalidation",
    "kind": "struct",
    "members": [
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "new_nonce",
        "type": "core::integer::u64",
        "kind": "data"
      },
      {
        "name": "old_nonce",
        "type": "core::integer::u64",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::allowance_transfer::AllowanceTransferComponent::Approval",
    "kind": "struct",
    "members": [
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "amount",
        "type": "core::integer::u256",
        "kind": "data"
      },
      {
        "name": "expiration",
        "type": "core::integer::u64",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::allowance_transfer::AllowanceTransferComponent::Permit",
    "kind": "struct",
    "members": [
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "amount",
        "type": "core::integer::u256",
        "kind": "data"
      },
      {
        "name": "expiration",
        "type": "core::integer::u64",
        "kind": "data"
      },
      {
        "name": "nonce",
        "type": "core::integer::u64",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::allowance_transfer::AllowanceTransferComponent::Lockdown",
    "kind": "struct",
    "members": [
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "token",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      },
      {
        "name": "spender",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::allowance_transfer::AllowanceTransferComponent::Event",
    "kind": "enum",
    "variants": [
      {
        "name": "NonceInvalidation",
        "type": "permit2::components::allowance_transfer::AllowanceTransferComponent::NonceInvalidation",
        "kind": "nested"
      },
      {
        "name": "Approval",
        "type": "permit2::components::allowance_transfer::AllowanceTransferComponent::Approval",
        "kind": "nested"
      },
      {
        "name": "Permit",
        "type": "permit2::components::allowance_transfer::AllowanceTransferComponent::Permit",
        "kind": "nested"
      },
      {
        "name": "Lockdown",
        "type": "permit2::components::allowance_transfer::AllowanceTransferComponent::Lockdown",
        "kind": "nested"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::signature_transfer::SignatureTransferComponent::Event",
    "kind": "enum",
    "variants": []
  },
  {
    "type": "event",
    "name": "permit2::components::unordered_nonces::UnorderedNoncesComponent::UnorderedNonceInvalidation",
    "kind": "struct",
    "members": [
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "nonce_space",
        "type": "core::felt252",
        "kind": "data"
      },
      {
        "name": "mask",
        "type": "core::felt252",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::unordered_nonces::UnorderedNoncesComponent::NonceInvalidated",
    "kind": "struct",
    "members": [
      {
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress",
        "kind": "key"
      },
      {
        "name": "nonce",
        "type": "core::felt252",
        "kind": "data"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::components::unordered_nonces::UnorderedNoncesComponent::Event",
    "kind": "enum",
    "variants": [
      {
        "name": "UnorderedNonceInvalidation",
        "type": "permit2::components::unordered_nonces::UnorderedNoncesComponent::UnorderedNonceInvalidation",
        "kind": "nested"
      },
      {
        "name": "NonceInvalidated",
        "type": "permit2::components::unordered_nonces::UnorderedNoncesComponent::NonceInvalidated",
        "kind": "nested"
      }
    ]
  },
  {
    "type": "event",
    "name": "permit2::permit2::Permit2::Event",
    "kind": "enum",
    "variants": [
      {
        "name": "AllowedTransferEvent",
        "type": "permit2::components::allowance_transfer::AllowanceTransferComponent::Event",
        "kind": "flat"
      },
      {
        "name": "SignatureTransferEvent",
        "type": "permit2::components::signature_transfer::SignatureTransferComponent::Event",
        "kind": "flat"
      },
      {
        "name": "UnorderedNoncesEvent",
        "type": "permit2::components::unordered_nonces::UnorderedNoncesComponent::Event",
        "kind": "flat"
      }
    ]
  }
] as const;
