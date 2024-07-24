import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_image/native.dart';

var imageProvider = FutureProvider.autoDispose
    .family<File, Map<String, String>>((ref, param) async {
  try {
    final rootIsolateToken = RootIsolateToken.instance!;
    final receivePort = ReceivePort();
    Isolate.spawn(snap, [receivePort.sendPort, param, rootIsolateToken]);
    final file = await receivePort.first as File;
    return file;
  } catch (error) {
    rethrow;
  }
});

Future<File> loadImageFromPath(String path) async {
  File imageFile = File(path);

  if (await imageFile.exists()) {
    return imageFile;
  } else {
    throw Exception('Image does not exist at path: $path');
  }
}

snap(List<dynamic> args) async {
  final sendPort = args[0];
  final param = args[1];
  final token = args[2];
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  try {
    var ret = await Native.instance.snap(param: param);
    if (ret?['status'] == 'error') {
      throw Exception(ret?['data']);
    }

    var file = await loadImageFromPath(ret?['data']);
    Isolate.exit(sendPort, file);
  } catch (error) {
    rethrow;
  }
}
