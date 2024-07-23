import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_image/image_provider.dart';

class MainPage extends ConsumerWidget {
  MainPage({super.key});

  final _imgFamily = imageProvider(
      {'origin': 'assets/origin.png', 'mask': 'assets/mask.jpeg'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var imageFuture = ref.watch(_imgFamily);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 10),
        width: double.infinity,
        child: Column(
          children: [
            SizedBox(
              width: size.width / 2,
              child: Image.asset(
                'assets/origin.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            SizedBox(
              width: size.width / 2,
              child: Image.asset('assets/mask.jpeg'),
            ),
            const SizedBox(
              height: 20,
            ),
            imageFuture.when(
                data: (file) => SizedBox(
                      width: size.width / 2,
                      child: Image.file(file),
                    ),
                error: (error, stack) => Text(
                      error.toString(),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                loading: () => const CircularProgressIndicator())
          ],
        ),
      ),
    );
  }
}
