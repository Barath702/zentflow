import 'dart:io';

String defaultDownloadsDir() {
  if (Platform.isAndroid) return '/storage/emulated/0/Download';
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) return '$home/Downloads';
  return Directory.current.path;
}

