#!/bin/bash
# codebase_dumper.sh - Fixed version

OUTPUT_FILE="codebase_dump.txt"
ROOT_DIR="${1:-.}"

: > "$OUTPUT_FILE"

{
    echo "=== CODEBASE DUMP ==="
    echo "Generated: $(date)"
    echo "Root: $ROOT_DIR"
    echo ""
} >> "$OUTPUT_FILE"

# Exclude secrets from dump!
find "$ROOT_DIR" -type f \
    ! -path "*/secrets/*" \
    ! -path "*/.git/*" \
    ! -name "*.log" \
    ! -name "$OUTPUT_FILE" \
    -print0 | sort -z | while IFS= read -r -d '' filepath; do
    
    # Skip binaries
    if file "$filepath" | grep -qE "binary|executable|image|compressed"; then
        continue
    fi
    
    {
        echo "========================================"
        echo "FILE: $filepath"
        echo "========================================"
        cat "$filepath"
        echo ""
        echo ""
    } >> "$OUTPUT_FILE"
done

echo "Done: $OUTPUT_FILE"