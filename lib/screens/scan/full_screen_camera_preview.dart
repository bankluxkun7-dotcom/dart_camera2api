import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _cameraChannel = MethodChannel('dart_camera2api/camera');

class FullScreenCameraPreview extends StatefulWidget {
  final int textureId;
  const FullScreenCameraPreview({required this.textureId, super.key});

  @override
  State<FullScreenCameraPreview> createState() => _FullScreenCameraPreviewState();
}

class _FullScreenCameraPreviewState extends State<FullScreenCameraPreview> {
  bool _isCapturing = false;
  bool _flashOn = false;
  Offset? _focusPoint;
  double _focusOpacity = 0.0;
  Timer? _focusTimer;

  Future<void> _capture() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final path = await _cameraChannel.invokeMethod<String>('takePicture');
      await _cameraChannel.invokeMethod('close');
      if (!mounted) return;
      Navigator.of(context).pop<String?>(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
      try {
        await _cameraChannel.invokeMethod('close');
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop<String?>(null);
    }
  }

  Future<bool> _onWillPop() async {
    try {
      await _cameraChannel.invokeMethod('close');
    } catch (_) {}
    return true;
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) async {
                      final dx = details.localPosition.dx;
                      final dy = details.localPosition.dy;
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final nx = (dx / w).clamp(0.0, 1.0);
                      final ny = (dy / h).clamp(0.0, 1.0);
                      try {
                        await _cameraChannel.invokeMethod('focusAt', {'x': nx, 'y': ny});
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Focus failed: $e')),
                          );
                        }
                      }

                      _focusTimer?.cancel();
                      setState(() {
                        _focusPoint = details.localPosition;
                        _focusOpacity = 1.0;
                      });
                      _focusTimer = Timer(
                        const Duration(milliseconds: 700),
                        () => setState(() => _focusOpacity = 0.0),
                      );
                    },
                    child: Texture(textureId: widget.textureId.toInt()),
                  );
                },
              ),
            ),
            if (_focusPoint != null)
              Positioned(
                left: (_focusPoint!.dx - 24).clamp(0.0, double.infinity),
                top: (_focusPoint!.dy - 24).clamp(0.0, double.infinity),
                child: AnimatedOpacity(
                  opacity: _focusOpacity,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              top: 40,
              child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: () async {
                  try {
                    await _cameraChannel.invokeMethod('close');
                  } catch (_) {}
                  if (mounted) Navigator.of(context).pop<String?>(null);
                },
              ),
            ),
            Positioned(
              right: 16,
              top: 40,
              child: IconButton(
                color: Colors.white,
                icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                onPressed: () async {
                  try {
                    final ok = await _cameraChannel.invokeMethod<bool>('setFlash', !_flashOn);
                    if (!mounted) return;
                    if (ok == true) setState(() => _flashOn = !_flashOn);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Flash toggle failed: $e')),
                    );
                  }
                },
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  onPressed: _capture,
                  child: _isCapturing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.camera_alt),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
