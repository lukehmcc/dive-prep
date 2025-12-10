import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart'; // Added for fallback

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
    // NOTE: On Desktop, users usually prefer 'Downloads', but 'Documents' is safer for sandboxing.
    // You can switch this to getDownloadsDirectory() if you are on a standard Linux distro.
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

  // --- IMPROVED OPEN FOLDER ---
  // Returns TRUE if successful, FALSE if failed.
  // Returns the PATH as a string so UI can show it to the user.
  Future<Map<String, dynamic>> openFolder() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = dir.path;

      // Desktop Strategies
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return {'success': true, 'path': path};
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
        return {'success': true, 'path': path};
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return {'success': true, 'path': path};
      }

      // Mobile/Fallback Strategy
      final result = await OpenFile.open(path);
      if (result.type == ResultType.done) {
        return {'success': true, 'path': path};
      }

      return {
        'success': false,
        'path': path,
        'msg': "No app found to open folder",
      };
    } catch (e) {
      return {'success': false, 'path': "Unknown", 'msg': e.toString()};
    }
  }
}
