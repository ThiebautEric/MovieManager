import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cover_ocr_service.dart';

sealed class PhotoSearchState {
  const PhotoSearchState();
}

class PhotoSearchIdle extends PhotoSearchState {
  const PhotoSearchIdle();
}

class PhotoSearchLoading extends PhotoSearchState {
  const PhotoSearchLoading();
}

class PhotoSearchDone extends PhotoSearchState {
  const PhotoSearchDone(this.query);
  final String query;
}

class PhotoSearchError extends PhotoSearchState {
  const PhotoSearchError(this.message);
  final String message;
}

final coverOcrServiceProvider = Provider<CoverOcrService>((_) => CoverOcrService());

class PhotoSearchNotifier extends Notifier<PhotoSearchState> {
  @override
  PhotoSearchState build() => const PhotoSearchIdle();

  Future<void> searchFromBytes(Uint8List bytes) async {
    state = const PhotoSearchLoading();
    try {
      final service = ref.read(coverOcrServiceProvider);
      final title = await service.extractTitle(bytes);
      if (title == null || title.isEmpty) {
        state = const PhotoSearchError('');
      } else {
        state = PhotoSearchDone(title);
      }
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? '';
      state = PhotoSearchError('HTTP ${e.response?.statusCode}: $body');
    } on Exception catch (e) {
      state = PhotoSearchError(e.toString());
    }
  }

  void reset() => state = const PhotoSearchIdle();
}

final photoSearchProvider =
    NotifierProvider<PhotoSearchNotifier, PhotoSearchState>(
        PhotoSearchNotifier.new);
