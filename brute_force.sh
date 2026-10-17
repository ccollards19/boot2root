#!/usr/bin/env bash
# Usage: ./brute_force.sh <password_list_file> <encrypted_key_file> [user@localhost]

set -u

PASSLIST="$1"
KEYFILE="$2"
TARGET="${3:-user@localhost}"

[ -f "$PASSLIST" ] || { echo "Password list not found: $PASSLIST"; exit 1; }
[ -f "$KEYFILE" ]   || { echo "Key file not found: $KEYFILE"; exit 1; }

# Make sure the key has safe permissions, or SSH will refuse it
chmod 600 "$KEYFILE"

echo "Trying passwords from '$PASSLIST' on key '$KEYFILE'..."

while IFS= read -r pass || [ -n "$pass" ]; do
    # Skip empty lines and comments
    [ -z "$pass" ] && continue
    [[ "$pass" == \#* ]] && continue

    if ssh-keygen -y -P "$pass" -f "$KEYFILE" >/dev/null 2>&1; then
        echo "FOUND: password is '$pass'"
        echo "Connecting to $TARGET..."
        exec ssh -i "$KEYFILE" "$TARGET" -p 6060
    fi
done < "$PASSLIST"

echo "No password from the list matched."
exit 1
