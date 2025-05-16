import 'dart:io';

class LogHelper {
  late IOSink _sink;

  LogHelper(String path) {
    final file = File(path);
    _sink = file.openWrite(mode: FileMode.write);
  }

  Future<void> log(String text) async {
    _sink.writeln('${DateTime.now().toIso8601String()} — $text');
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
