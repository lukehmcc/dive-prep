import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/jellyfin_models.dart';
import '../../services/download_service.dart';
import 'download_state.dart';

class DownloadCubit extends Cubit<DownloadState> {
  final DownloadService _service;
  
  final Map<String, int> _lastBytes = {};
  final Map<String, int> _lastTime = {};

  DownloadCubit(this._service) : super(const DownloadState(tasks: [])) {
    _loadTasks();
  }

  // --- PERSISTENCE LOGIC ---
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('saved_tasks');
    
    if (tasksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        final List<TaskRecord> loadedTasks = decoded.map((e) => TaskRecord.fromMap(e)).toList();
        
        // Sanitize: If app crashed while running, mark those as paused
        final sanitizedTasks = loadedTasks.map((t) {
          if (t.status == TaskStatus.running) {
            return t.copyWith(status: TaskStatus.paused, speed: '');
          }
          return t;
        }).toList();

        emit(DownloadState(tasks: sanitizedTasks));
      } catch (e) {
        // Fallback if data corrupt
        emit(const DownloadState(tasks: []));
      }
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = state.tasks.map((e) => e.toMap()).toList();
    await prefs.setString('saved_tasks', jsonEncode(data));
  }
  // -------------------------

  Future<void> startDownload(String url, String filename, String token, {String? metaData}) async {
    final taskId = filename.hashCode.toString();
    
    int estimatedSize = 0;
    if (metaData != null && metaData.contains('size:')) {
      try {
        final parts = metaData.split('|');
        final sizePart = parts.firstWhere((p) => p.startsWith('size:'));
        estimatedSize = int.parse(sizePart.split(':')[1]);
      } catch (_) {}
    }

    final task = DownloadTask(
      taskId: taskId, 
      url: url, 
      filename: filename, 
      metaData: metaData ?? ""
    );

    final newTasks = List<TaskRecord>.from(state.tasks);
    newTasks.removeWhere((t) => t.task.taskId == taskId);
    newTasks.insert(0, TaskRecord(task: task, status: TaskStatus.running, progress: 0.0, speed: "Starting.."));
    
    emit(DownloadState(tasks: newTasks));
    _saveTasks(); // Save immediately

    int fileStart = await _service.getFileSize(filename);

    try {
      await _service.downloadFile(
        url: url,
        filename: filename,
        token: token,
        startByte: fileStart,
        onProgress: (received, total) {
           _onProgress(taskId, fileStart + received, estimatedSize);
        }
      );
      _updateStatus(taskId, TaskStatus.complete, 1.0);
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        _updateStatus(taskId, TaskStatus.paused, null);
      } else {
        _updateStatus(taskId, TaskStatus.failed, null);
      }
    }
  }

  void _onProgress(String taskId, int totalReceived, int estimatedTotal) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastT = _lastTime[taskId] ?? 0;
    
    if (now - lastT > 1000) {
      final lastB = _lastBytes[taskId] ?? 0;
      final bytesDiff = totalReceived - lastB;
      final timeDiff = (now - lastT) / 1000.0;
      String speedStr = "0 MB/s";
      
      if (timeDiff > 0) {
        final mbPerSec = (bytesDiff / timeDiff) / (1024 * 1024);
        speedStr = "${mbPerSec.toStringAsFixed(2)} MB/s";
      }

      _lastBytes[taskId] = totalReceived;
      _lastTime[taskId] = now;
      
      double pct = 0.0;
      if (estimatedTotal > 0) pct = totalReceived / estimatedTotal;
      if (pct > 0.99) pct = 0.99;

      final index = state.tasks.indexWhere((t) => t.task.taskId == taskId);
      if (index != -1) {
        final updatedTasks = List<TaskRecord>.from(state.tasks);
        updatedTasks[index] = updatedTasks[index].copyWith(progress: pct, speed: speedStr);
        emit(DownloadState(tasks: updatedTasks));
        // Note: We don't save to disk on every progress tick (performance), only on status change
      }
    }
  }

  void _updateStatus(String taskId, TaskStatus status, double? finalProgress) {
    final index = state.tasks.indexWhere((t) => t.task.taskId == taskId);
    if (index != -1) {
      final updatedTasks = List<TaskRecord>.from(state.tasks);
      updatedTasks[index] = updatedTasks[index].copyWith(
        status: status, 
        progress: finalProgress
      );
      emit(DownloadState(tasks: updatedTasks));
      _saveTasks(); // Save on status change
    }
    _cleanup(taskId);
  }

  void pauseDownload(String taskId) {
    _service.cancelDownload(taskId);
    // Logic: Cancel triggers 'catch', which calls _updateStatus(paused), which calls _saveTasks.
  }

  Future<void> deleteRecord(TaskRecord record) async {
    pauseDownload(record.task.taskId);
    await _service.deleteFile(record.task.filename);
    final updatedTasks = List<TaskRecord>.from(state.tasks);
    updatedTasks.removeWhere((t) => t.task.taskId == record.task.taskId);
    emit(DownloadState(tasks: updatedTasks));
    _saveTasks(); // Save deletion
  }

  void _cleanup(String taskId) {
    _lastBytes.remove(taskId);
    _lastTime.remove(taskId);
  }

  Future<Map<String, dynamic>> openFolder() async {
    return await _service.openFolder();
  }
}
