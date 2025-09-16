set -e

flutter gen-l10n
flutter build "$@"
