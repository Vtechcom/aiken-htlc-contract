#!/usr/bin/env bash
set -euo pipefail

# Build contract
aiken build

# Create output directory if it doesn't exist
mkdir -p .output

# Function to convert a single validator
convert_validator() {
    local VALIDATOR="$1"
    
    # Extract module name (first part before first dot)
    local MODULE_NAME=$(echo "$VALIDATOR" | cut -d'.' -f1)
    
    # Tên file output (ví dụ .output/always_true.plutus.json)
    local OUTFILE=".output/${MODULE_NAME}.plutus.json"

    # 1. Convert validator thành JSON Plutus script
    aiken blueprint convert --validator "$VALIDATOR" > "$OUTFILE"

    # 2. Lấy địa chỉ từ validator
    local ADDR=$(aiken blueprint address --validator "$VALIDATOR")

    # 3. Dùng jq để thêm field "address"
    jq --arg addr "$ADDR" '. + {address: $addr}' "$OUTFILE" > tmp.json && mv tmp.json "$OUTFILE"

    echo "✅ Generated $OUTFILE with address:"
    echo "------------------------------------"
    cat "$OUTFILE" | jq
    echo ""
}

# Check if validator name is provided
if [ $# -eq 0 ]; then
    echo "🔍 No validator specified. Scanning all validators from plutus.json..."
    echo "=================================================================="
    
    # Extract all validator titles that end with ".spend" from plutus.json
    VALIDATORS=$(jq -r '.validators[] | select(.title | endswith(".spend")) | .title' plutus.json)
    
    if [ -z "$VALIDATORS" ]; then
        echo "❌ No spend validators found in plutus.json"
        exit 1
    fi
    
    # Convert each validator
    while IFS= read -r validator; do
        if [ -n "$validator" ]; then
            # Extract module name (first part before first dot)
            validator_module=$(echo "$validator" | cut -d'.' -f1)
            echo "🔨 Converting validator: $validator_module"
            convert_validator "$validator_module"
        fi
    done <<< "$VALIDATORS"
    
    echo "🎉 All validators converted successfully!"
else
    # Single validator mode
    # Extract module name (first part before first dot)
    VALIDATOR="$1"
    validator_module=$(echo "$VALIDATOR" | cut -d'.' -f1)
    echo "🔨 Converting single validator: $validator_module"
    convert_validator "$validator_module"
fi
