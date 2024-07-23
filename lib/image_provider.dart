import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_image/native.dart';

var imageProvider = FutureProvider.autoDispose
    .family<File, Map<String, String>>((ref, param) async {
  try {
    var ret = await Native.instance.snap(param: param);
    if (ret?['status'] == 'error') {
      throw Exception(ret?['data']);
    }

    return await loadImageFromPath(ret?['data']);
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
