# HTLC Validator - Smart Contract

## Giới thiệu (Introduction)

HTLC (Hash Time Locked Contract) là một smart contract cho phép thực hiện giao dịch có điều kiện với khóa thời gian và hash lock. Contract này được viết bằng Aiken cho Cardano blockchain.

## Tính năng (Features)

- ✅ Hash Lock: Khóa giao dịch bằng hash
- ✅ Time Lock: Khóa thời gian tự động
- ✅ Refund: Hoàn tiền sau khi hết hạn
- ✅ Claim: Nhận tiền khi có secret đúng

## Cài đặt (Installation)

```bash
# Clone repository
git clone <your-repo-url>
cd aiken-htlc-contract

# Cài đặt Aiken
curl -sSfL https://install.aiken-lang.org | bash

# Build contract
aiken build
```

## Sử dụng Contract (Usage)

### 1. Build Contract

```bash
aiken build
```

### 2. Apply Parameters vào Contract

Để áp dụng parameters (tham số) vào contract, chạy lệnh:

```bash
aiken blueprint apply
```

Terminal sẽ yêu cầu bạn nhập parameter:

```
aiken blueprint apply
  Analyzing blueprint
>      Asking VerificationKeyHash (a byte-array): ___
```

Nhập giá trị VerificationKeyHash (public key hash của bạn) và nhấn Enter:

```
aiken blueprint apply
    Analyzing blueprint
>      Asking VerificationKeyHash (a byte-array): 581ce06f2ae361f33815f775b224789025dccc4b6413599224e70841eebf
     Applying 581ce06f2ae361f33815f775b224789025dccc4b6413599224e70841eebf
```

Kết quả sẽ tạo ra một blueprint với compiled code đã được apply parameters, chứa thông tin:
- Validator hash
- Compiled code với parameters
- Schema định nghĩa cho datum và redeemer

### 3. Deploy Contract lên Testnet

```bash
# Generate validator script
aiken blueprint convert -v htlc_validator > htlc.plutus

# Tạo script address
cardano-cli address build \
  --payment-script-file htlc.plutus \
  --testnet-magic 1097911063 \
  --out-file htlc.addr
```

### 4. Lock Funds (Khóa tiền)

```bash
# Tạo datum với hash và deadline
cardano-cli transaction build \
  --tx-in <YOUR_UTXO> \
  --tx-out $(cat htlc.addr)+<AMOUNT> \
  --tx-out-datum-hash <DATUM_HASH> \
  --change-address <YOUR_ADDRESS> \
  --testnet-magic 1097911063 \
  --out-file lock.unsigned

# Sign và submit
cardano-cli transaction sign \
  --tx-body-file lock.unsigned \
  --signing-key-file payment.skey \
  --testnet-magic 1097911063 \
  --out-file lock.signed

cardano-cli transaction submit \
  --tx-file lock.signed \
  --testnet-magic 1097911063
```

### 5. Claim Funds (Nhận tiền)

```bash
# Unlock với secret
cardano-cli transaction build \
  --tx-in <SCRIPT_UTXO> \
  --tx-in-script-file htlc.plutus \
  --tx-in-datum-file datum.json \
  --tx-in-redeemer-file redeemer.json \
  --tx-out <BENEFICIARY_ADDRESS>+<AMOUNT> \
  --change-address <BENEFICIARY_ADDRESS> \
  --testnet-magic 1097911063 \
  --out-file claim.unsigned
```

## Cấu trúc Datum & Redeemer

### Datum Structure
```json
{
  "constructor": 0,
  "fields": [
  {"bytes": "hash_of_secret"},
  {"int": 1234567890},
  {"bytes": "beneficiary_pub_key_hash"}
  ]
}
```

### Redeemer Structure
```json
{
  "constructor": 0,
  "fields": [
  {"bytes": "secret_preimage"}
  ]
}
```

## Testing

```bash
# Chạy tests
aiken check

# Format code
aiken fmt
```

## Lưu ý quan trọng (Important Notes)

- ⚠️ Test kỹ trên testnet trước khi deploy mainnet
- 🔒 Giữ secret an toàn cho đến khi claim
- ⏰ Chú ý deadline để tránh mất tiền
- 💡 Luôn kiểm tra datum và redeemer format
- 📝 Apply parameters trước khi deploy để có địa chỉ script chính xác

## Hỗ trợ (Support)

Nếu bạn gặp vấn đề gì, hãy tạo issue trên repository này nhé! 😊

---
Made with ❤️ by Ania
