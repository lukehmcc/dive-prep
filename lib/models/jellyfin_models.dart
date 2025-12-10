import 'dart:convert';
import 'package:dio/dio.dart';

class JellyfinItem {
  final String id;
  final String name;
  final String type;
  final String? imageTag;
  final int? indexNumber;
  final int? runTimeTicks;
  final String? container;
  final int? size;

  JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.imageTag,
    this.indexNumber,
    this.runTimeTicks,
    this.container,
    this.size,
  });

  factory JellyfinItem.fromJson(Map<String, dynamic> json) {
    String? container;
    int? size;
    
    if (json['MediaSources'] != null) {
      final list = json['MediaSources'] as List;
      if (list.isNotEmpty) {
        container = list[0]['Container'];
        size = list[0]['Size'];
      }
    }

    return JellyfinItem(
      id: json['Id'],
      name: json['Name'] ?? 'Unknown',
      type: json['Type'] ?? 'Unknown',
      imageTag: json['ImageTags']?['Primary'],
      indexNumber: json['IndexNumber'],
      runTimeTicks: json['RunTimeTicks'],
      container: container,
      size: size,
    );
  }
}

class MediaSource {
  final String id;
  final String name;
  final String container;
  final int size;

  MediaSource({
    required this.id,
    required this.name,
    required this.container,
    required this.size,
  });

  factory MediaSource.fromJson(Map<String, dynamic> json) {
    return MediaSource(
      id: json['Id'],
      name: json['Name'] ?? 'Default',
      container: json['Container'] ?? 'mkv',
      size: json['Size'] ?? 0,
    );
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(1)} MB';
    return '${(size / 1073741824).toStringAsFixed(2)} GB';
  }
}

class QualityProfile {
  final String label;
  final int bitrate;
  final int? width;

  QualityProfile(this.label, this.bitrate, {this.width});
}

// --- UPDATED DOWNLOAD MODELS FOR PERSISTENCE ---

enum TaskStatus { enqueued, running, paused, failed, complete }

class DownloadTask {
  final String taskId;
  final String url;
  final String filename;
  final String metaData;

  DownloadTask({
    required this.taskId,
    required this.url,
    required this.filename,
    required this.metaData,
  });

  // Convert to Map for saving
  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'url': url,
      'filename': filename,
      'metaData': metaData,
    };
  }

  // Load from Map
  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      taskId: map['taskId'] ?? '',
      url: map['url'] ?? '',
      filename: map['filename'] ?? '',
      metaData: map['metaData'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());
  factory DownloadTask.fromJson(String source) => DownloadTask.fromMap(json.decode(source));
}

class TaskRecord {
  final DownloadTask task;
  final TaskStatus status;
  final double progress;
  final String speed;

  TaskRecord({
    required this.task,
    required this.status,
    required this.progress,
    required this.speed,
  });

  TaskRecord copyWith({
    TaskStatus? status,
    double? progress,
    String? speed,
  }) {
    return TaskRecord(
      task: task,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
    );
  }

  // Serialize Record
  Map<String, dynamic> toMap() {
    return {
      'task': task.toMap(),
      'status': status.index, // Save enum index
      'progress': progress,
    };
  }

  factory TaskRecord.fromMap(Map<String, dynamic> map) {
    return TaskRecord(
      task: DownloadTask.fromMap(map['task']),
      status: TaskStatus.values[map['status'] ?? 0],
      progress: map['progress'] ?? 0.0,
      speed: '', // Don't save speed, it's transient
    );
  }
  
  String toJson() => json.encode(toMap());
  factory TaskRecord.fromJson(String source) => TaskRecord.fromMap(json.decode(source));
}
