import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Map<String, CancelToken> _tokens = {};

  Future<void> downloadFile({
    required String url,
    required String filename,
    required String token,
    required int startByte,
    required Function(int received, int total) onProgress,
  }) async {
    final savePath = await getFilePath(filename);
    final cancelToken = CancelToken();
    final taskId = filename.hashCode.toString();
    _tokens[taskId] = cancelToken;

    final dio = Dio();
    final headers = {'X-MediaBrowser-Token': token};
    if (startByte > 0) {
      headers['Range'] = 'bytes=$startByte-';
    }

    try {
      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(headers: headers, responseType: ResponseType.stream),
        onReceiveProgress: onProgress,
      );
    } finally {
      _tokens.remove(taskId);
    }
  }

  void cancelDownload(String taskId) {
    if (_tokens.containsKey(taskId)) {
      _tokens[taskId]!.cancel();
      _tokens.remove(taskId);
    }
  }

  Future<String> getFilePath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return "${dir.path}/$filename";
  }

  Future<int> getFileSize(String filename) async {
    final path = await getFilePath(filename);
    final file = File(path);
    if (await file.exists()) return await file.length();
    return 0;
  }
  
  Future<void> deleteFile(String filename) async {
     final path = await getFilePath(filename);
     final file = File(path);
     if (await file.exists()) await file.delete();
  }
}
