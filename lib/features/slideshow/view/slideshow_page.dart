import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cactro_test_mobile/features/slideshow/core/export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum SlideShowAnimation { fade, slide }

class SlideshowPage extends StatefulWidget {
  const SlideshowPage({super.key, required this.images});

  final List<XFile> images;

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  @override
  void initState() {
    playAudio();
    startSlideshow();
    super.initState();
  }

  @override
  void dispose() {
    stopAudio();
    _slideshowTimer.cancel();
    super.dispose();
  }

  // slide show control
  SlideShowAnimation currentAnimation = SlideShowAnimation.fade;
  late final Timer _slideshowTimer;
  int currentIndex = 0;

  void startSlideshow() {
    _slideshowTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        currentIndex = (currentIndex + 1) % widget.images.length;
      });
    });
  }

  // audio player
  final player = AudioPlayer();

  Future<void> playAudio() async {
    await player.play(AssetSource('music.mp3', mimeType: "audio/mp3"));
    await player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> stopAudio() async {
    await player.stop();
    await player.dispose();
  }

  // download file
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;

      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true; // iOS doesn't need this
  }

  Future<File> captureCurrentFrame(String path) async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    final file = File(path);
    await file.writeAsBytes(buffer);
    return file;
  }

  Future<void> downloadFile() async {
    if (Platform.isAndroid) {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permission required to save to Downloads"),
          ),
        );
        return;
      }
    }
    final frameDir = Directory(
      '${(await getTemporaryDirectory()).path}/frames',
    );
    if (!frameDir.existsSync()) frameDir.createSync();

    List<File> frameImages = [];

    for (int i = 0; i < widget.images.length; i++) {
      setState(() {
        currentIndex = i;
      });
      await Future.delayed(Duration(seconds: 1)); // animation duration
      final file = await captureCurrentFrame('${frameDir.path}/frame_$i.png');
      frameImages.add(file);
    }

    // 1. Copy the bundled audio file to a temp location
    final musicByteData = await rootBundle.load('assets/music.mp3');
    final tempDir = await getTemporaryDirectory();
    final musicFile = File('${tempDir.path}/music.mp3');
    await musicFile.writeAsBytes(musicByteData.buffer.asUint8List());

    // 2. Export video using core/export.dart
    final exportedVideoPath = await exportSlideshowVideo(
      imageFiles: frameImages,
      musicFile: musicFile,
    );

    // 3. Show result
    if (exportedVideoPath != null && context.mounted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video exported to $exportedVideoPath')),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed')));
      Navigator.pop(context);
    }
  }

  // keys for video export
  final GlobalKey _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slideshow'),
        actions: [
          IconButton(
            onPressed: () => downloadFile(),
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          children: [
            Image.network(
              'https://img.freepik.com/free-vector/simple-blue-gradient-background-vector-business_53876-166894.jpg',
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
            ),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                transitionBuilder: (child, animation) {
                  switch (currentAnimation) {
                    case SlideShowAnimation.fade:
                      return FadeTransition(opacity: animation, child: child);
                    case SlideShowAnimation.slide:
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                  }
                },
                child: Image.file(
                  File(widget.images[currentIndex].path),
                  key: ValueKey(currentIndex),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // control transition style
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {
                      currentAnimation = SlideShowAnimation.fade;
                    }),
                    child: const Text("Fade"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      currentAnimation = SlideShowAnimation.slide;
                    }),
                    child: const Text("Slide"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
