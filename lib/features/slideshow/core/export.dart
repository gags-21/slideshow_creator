import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:external_path/external_path.dart';

Future<String> getAndroidDownloadPath() async {
  return await ExternalPath.getExternalStoragePublicDirectory(
    ExternalPath.DIRECTORY_DOWNLOAD,
  );
}

Future<String?> exportSlideshowVideo({
  required List<File> imageFiles,
  required File musicFile,
}) async {
  // 1. Prepare temporary paths
  final dir = await getTemporaryDirectory();
  final frameDir = Directory('${dir.path}/frames');
  if (!frameDir.existsSync()) frameDir.createSync(recursive: true);

  // 2. Copy frames
  for (int i = 0; i < imageFiles.length; i++) {
    final filename = 'frame_${i.toString().padLeft(2, '0')}.png';
    await imageFiles[i].copy('${frameDir.path}/$filename');
  }

  final outputVideoPath = '${dir.path}/slideshow.mp4';
  final finalVideoPath = '${dir.path}/final_slideshow.mp4';

  // 3. FFmpeg: Generate slideshow from images
  final cmd1 =
      '-y -framerate 1/3 -i "${frameDir.path}/frame_%02d.png" -vf format=yuv420p "$outputVideoPath"';
  final session1 = await FFmpegKit.execute(cmd1);
  final returnCode1 = await session1.getReturnCode();

  if (returnCode1?.isValueSuccess() != true ||
      !File(outputVideoPath).existsSync()) {
    print('FFmpeg slideshow creation failed');
    return null;
  }

  // 4. FFmpeg: Merge with audio
  print(File(outputVideoPath).existsSync()); // should be true
  print(File(musicFile.path).existsSync()); // should be true

  final cmd2 =
      '-y -i "$outputVideoPath" -i "${musicFile.path}" -shortest -c:v libx264 -c:a aac -b:a 192k -pix_fmt yuv420p "$finalVideoPath"';

  final session2 = await FFmpegKit.execute(cmd2);
  final returnCode2 = await session2.getReturnCode();

  if (returnCode2?.isValueSuccess() != true ||
      !File(finalVideoPath).existsSync()) {
    print('FFmpeg audio merge failed');
    return null;
  }

  // 5. Save to Downloads (Android)
  if (Platform.isAndroid) {
    final downloadsPath = await getAndroidDownloadPath();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savedVideo = File('$downloadsPath/slideshow_$timestamp.mp4');

    try {
      await File(finalVideoPath).copy(savedVideo.path);
      return savedVideo.path;
    } catch (e) {
      print('Error copying to Downloads: $e');
      return null;
    }
  }

  return finalVideoPath;
}
