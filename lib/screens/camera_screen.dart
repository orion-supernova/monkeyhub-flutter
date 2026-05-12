import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Captures a still photo using [ImagePicker.pickImage(source: camera)] which
/// presents the platform camera UI. Returns the captured [File] (or null).
///
/// We use image_picker rather than the full `camera` plugin to avoid the
/// extra surface area (preview rendering, lifecycle, AVCaptureSession permission
/// quirks). image_picker already declares NSCameraUsageDescription support and
/// works cross-platform.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    final picker = ImagePicker();
    try {
      final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 88);
      if (!mounted) return;
      Navigator.of(context).pop<File?>(shot == null ? null : File(shot.path));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop<File?>(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
