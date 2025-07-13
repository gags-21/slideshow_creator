import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  Future<void> downloadFile() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slideshow'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
      body: Stack(
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
    );
  }
}
