import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

export '../../l10n/gen/app_localizations.dart';

/// Raccourci : `context.l10n.maCle` au lieu de `AppLocalizations.of(context)`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
