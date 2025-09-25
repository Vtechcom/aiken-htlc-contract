use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKeyHash, sha2_256}
use aiken/interval.{Finite, between}
use cardano/address.{Address, Script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}

pub type HTLCDatum {
  secret_hash: ByteArray,
  timeout: Int,
  // PosixTime as Int in v2
  owner: VerificationKeyHash,
}

pub type HTLCRedeemer {
  Claim { secret: ByteArray }
  Refund
}

// Function to create fee value (1 ADA = 1,000,000 lovelace)
fn fee_value() -> Int {
  1000000
}

// Check if the required fee has been paid to team address
fn fee_paid(
  tx: Transaction,
  team_address: VerificationKeyHash,
  required_fee: Int,
) -> Bool {
  list.any(
    tx.outputs,
    fn(output: Output) {
      when output.address.payment_credential is {
        address.VerificationKey(vk_hash) ->
          vk_hash == team_address && assets.lovelace_of(output.value) >= required_fee
        _ -> False
      }
    },
  )
}

// Check if the transaction is signed by the owner
fn signed_by_owner(tx: Transaction, owner: VerificationKeyHash) -> Bool {
  list.has(tx.extra_signatories, owner)
}

// Check if the deadline has passed
fn deadline_passed(timeout: Int, current_time: Int) -> Bool {
  current_time > timeout
}

// Get the current time from the transaction validity range
fn get_current_time(tx: Transaction) -> Int {
  when tx.validity_range.lower_bound.bound_type is {
    Finite(lower) -> lower
    _ -> 0
  }
}

const team_address: VerificationKeyHash =
  #"e06f2ae361f33815f775b224789025dccc4b6413599224e70841eebf"

validator htlc_validator() {
  spend(
    datum: Option<HTLCDatum>,
    redeemer: HTLCRedeemer,
    _output_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(htlc_datum) = datum
    let current_time = get_current_time(tx)
    let required_fee = fee_value()
    when redeemer is {
      Claim { secret } -> {
        // Verify secret hash matches
        let secret_valid = sha2_256(secret) == htlc_datum.secret_hash
        // Check deadline hasn't passed
        let not_expired = !deadline_passed(htlc_datum.timeout, current_time)
        // Check fee is paid
        let fee_valid = fee_paid(tx, team_address, required_fee)
        secret_valid && not_expired && fee_valid
      }
      Refund -> {
        // Must be signed by owner
        let owner_signed = signed_by_owner(tx, htlc_datum.owner)
        // Deadline must have passed
        let expired = deadline_passed(htlc_datum.timeout, current_time)
        // Check fee is paid
        let fee_valid = fee_paid(tx, team_address, required_fee)
        owner_signed && expired && fee_valid
      }
    }
  }

  else(_) {
    fail
  }
}

// Test constants
const test_owner: VerificationKeyHash =
  #"4d04bcc73103cb8296abce92daefde484d498af9900729394b25f5e5"

const test_secret: ByteArray = "test_secret"

const test_secret_hash: ByteArray = sha2_256(test_secret)

const placeholder_utxo =
  OutputReference {
    transaction_id: #"94dddf4e6b9e4c5e749f0e120a5db0e40a870e4e1741dd3fdf6a6a1f1142ac2a",
    output_index: 0,
  }

// Test: Successful claim with valid secret
test test_claim_valid() {
  let datum =
    HTLCDatum {
      secret_hash: test_secret_hash,
      timeout: 2000000000,
      // Future timestamp
      owner: test_owner,
    }
  let redeemer = Claim { secret: test_secret }
  let team_output =
    Output {
      address: Address {
        payment_credential: address.VerificationKey(team_address),
        stake_credential: None,
      },
      value: from_lovelace(fee_value()),
      datum: InlineDatum(None),
      reference_script: None,
    }
  htlc_validator.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    Transaction {
      ..transaction.placeholder,
      outputs: [team_output],
      validity_range: between(1000000000, 1500000000),
      extra_signatories: [],
    },
  )
}

// Test: Failed claim with wrong secret
test test_claim_invalid_secret() fail {
  let datum =
    HTLCDatum {
      secret_hash: test_secret_hash,
      timeout: 2000000000,
      owner: test_owner,
    }
  let wrong_secret = "wrong_secret"
  let redeemer = Claim { secret: wrong_secret }
  let team_output =
    Output {
      address: Address {
        payment_credential: address.VerificationKey(team_address),
        stake_credential: None,
      },
      value: from_lovelace(fee_value()),
      datum: InlineDatum(None),
      reference_script: None,
    }
  htlc_validator.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    Transaction {
      ..transaction.placeholder,
      outputs: [team_output],
      validity_range: between(1000000000, 1500000000),
      extra_signatories: [],
    },
  )
}

// Test: Failed claim after deadline
test test_claim_after_deadline() fail {
  let datum =
    HTLCDatum {
      secret_hash: test_secret_hash,
      timeout: 1000000000,
      // Past timestamp
      owner: test_owner,
    }
  let redeemer = Claim { secret: test_secret }
  let team_output =
    Output {
      address: Address {
        payment_credential: address.VerificationKey(team_address),
        stake_credential: None,
      },
      value: from_lovelace(fee_value()),
      datum: InlineDatum(None),
      reference_script: None,
    }
  htlc_validator.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    Transaction {
      ..transaction.placeholder,
      outputs: [team_output],
      validity_range: between(1500000000, 2000000000),
      extra_signatories: [],
    },
  )
}

// Test: Successful refund by owner after deadline
test test_refund_valid() {
  let datum =
    HTLCDatum {
      secret_hash: test_secret_hash,
      timeout: 1000000000,
      // Past timestamp
      owner: test_owner,
    }
  let redeemer = Refund
  let team_output =
    Output {
      address: Address {
        payment_credential: address.VerificationKey(team_address),
        stake_credential: None,
      },
      value: from_lovelace(fee_value()),
      datum: InlineDatum(None),
      reference_script: None,
    }
  htlc_validator.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    Transaction {
      ..transaction.placeholder,
      outputs: [team_output],
      validity_range: between(1500000000, 2000000000),
      extra_signatories: [test_owner],
    },
  )
  // Owner signature
}

// Test: Failed refund before deadline
test test_refund_before_deadline() fail {
  let datum =
    HTLCDatum {
      secret_hash: test_secret_hash,
      timeout: 2000000000,
      // Future timestamp
      owner: test_owner,
    }
  let redeemer = Refund
  let team_output =
    Output {
      address: Address {
        payment_credential: address.VerificationKey(team_address),
        stake_credential: None,
      },
      value: from_lovelace(fee_value()),
      datum: InlineDatum(None),
      reference_script: None,
    }
  htlc_validator.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    Transaction {
      ..transaction.placeholder,
      outputs: [team_output],
      validity_range: between(1000000000, 1500000000),
      extra_signatories: [test_owner],
    },
  )
}

// Test: Failed refund without owner signature
test test_refund_not_signed() fail {
  let datum =
    HTLCDatum {
      secret_hash: test_secret_hash,
      timeout: 1000000000,
      // Past timestamp
      owner: test_owner,
    }
  let redeemer = Refund
  let team_output =
    Output {
      address: Address {
        payment_credential: address.VerificationKey(team_address),
        stake_credential: None,
      },
      value: from_lovelace(fee_value()),
      datum: InlineDatum(None),
      reference_script: None,
    }
  htlc_validator.spend(
    Some(datum),
    redeemer,
    placeholder_utxo,
    Transaction {
      ..transaction.placeholder,
      outputs: [team_output],
      validity_range: between(1500000000, 2000000000),
      extra_signatories: [],
    },
  )
  // No owner signature
}
