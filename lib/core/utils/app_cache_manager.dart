import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque partagé pour toutes les images TMDB.
/// Limite portée à 5 000 objets (défaut : 200) pour couvrir les grandes
/// collections sans évincer les affiches en cours de session.
class AppCacheManager extends CacheManager with ImageCacheManager {
  static const _key = 'tmdb_image_cache';

  static final AppCacheManager instance = AppCacheManager._();

  AppCacheManager._()
      : super(Config(
          _key,
          maxNrOfCacheObjects: 5000,
          stalePeriod: const Duration(days: 90),
        ));
}
