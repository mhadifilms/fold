#!/bin/zsh
set -euo pipefail
# Credentials must already be stored with notarytool store-credentials.
# This script never accepts a password as an argument or writes one to disk.
if (( $# != 2 )); then
  print -u2 'Usage: scripts/notarize.sh /path/to/Fold.app /path/to/notary-work-directory'
  exit 2
fi
fold_app="${1:A}"
fold_work="${2:A}"
fold_profile="${NOTARY_PROFILE:-fold-notary}"
[[ -d "$fold_app/Contents" ]] || { print -u2 'App bundle not found'; exit 2; }
mkdir -p "$fold_work"
codesign --verify --deep --strict "$fold_app"
# Check login before creating or uploading an archive.
xcrun notarytool history --keychain-profile "$fold_profile" --output-format json > "$fold_work/history.json"
ditto -c -k --keepParent --sequesterRsrc "$fold_app" "$fold_work/submission.zip"
xcrun notarytool submit "$fold_work/submission.zip" --keychain-profile "$fold_profile" --wait --timeout 15m --output-format json > "$fold_work/submission.json"
[[ "$(plutil -extract status raw -o - "$fold_work/submission.json")" == Accepted ]] || {
  print -u2 "Apple did not accept the submission. See $fold_work/submission.json"
  exit 1
}
xcrun stapler staple "$fold_app"
xcrun stapler validate "$fold_app"
codesign --verify --deep --strict "$fold_app"
spctl --assess --type execute --verbose=2 "$fold_app"
# Repack after stapling so the download includes Apple's ticket.
ditto -c -k --keepParent --sequesterRsrc "$fold_app" "$fold_work/Fold.zip"
print "Notarized and stapled: $fold_work/Fold.zip"
