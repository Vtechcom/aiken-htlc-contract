# HTLC Validator - Smart Contract

## Giới thiệu (Introduction)

HTLC (Hash Time Locked Contract) là một smart contract cho phép thực hiện giao dịch có điều kiện với khóa thời gian và hash lock. Contract này được viết bằng Aiken cho Cardano blockchain.

**Repo này được viết lại dựa trên https://github.com/AngeYobo/htlc-contract-aiken.git với aiken v1.1.17 và aiken-lang/stdlib v2.2.0**

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

### 2. Convert Contract sang Plutus Script

```bash
# Windows PowerShell
.\compile.ps1

# Hoặc Linux/Mac bash
./compile.sh
```

Script sẽ tự động:
- Build contract với `aiken build`
- Convert validator sang JSON format
- Lưu kết quả tại `.output/htlc_validator.plutus.json`

### 3. Deploy Contract lên Testnet

```bash
# Generate validator script từ file đã convert
cp .output/htlc_validator.plutus.json htlc.plutus.json

# Tạo script address
cardano-cli address build \
  --payment-script-file htlc.plutus.json \
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
  --tx-in-script-file htlc.plutus.json \
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
- 📝 Contract không cần apply parameters, sẵn sàng deploy ngay sau khi build

## Hỗ trợ (Support)

Nếu bạn gặp vấn đề gì, hãy tạo issue trên repository này nhé! 😊

## Liên quan (Related Links)

### Tài liệu kỹ thuật (Technical Documentation)
- 🔗 [Interledger RFC - Hashed Timelock Agreements](https://interledger.org/developers/rfcs/hashed-timelock-agreements/) - Đặc tả kỹ thuật HTLC
- 🔗 [eUTXO L2 Interoperability](https://cardano-scaling.github.io/eutxo-l2-interop/index.html) - Khả năng tương tác giữa các Layer 2
- 🔗 [eUTXO L2 Interop - Milestone 1](https://cardano-scaling.github.io/eutxo-l2-interop/ms1/index.html) - Chi tiết implementation

### GitHub Issues & Discussions
- 🔗 [Hydra Issue #2080](https://github.com/cardano-scaling/hydra/issues/2080) - Thảo luận về HTLC implementation

---
Made with ❤️ by Ania
