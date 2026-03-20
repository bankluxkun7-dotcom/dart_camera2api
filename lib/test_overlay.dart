import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class TestOverlay extends StatelessWidget {
  const TestOverlay({
    super.key,
    required this.imageFile,
    required this.detectedNames,
    required this.detectedBboxes,
  });

  final File imageFile;
  final List<String> detectedNames;
  final List<List<double>> detectedBboxes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test BBox Overlay')),
      body: Center(
        child: FutureBuilder<ImageInfo>(
          future: _getImageInfo(imageFile),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final imageInfo = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final imgW = imageInfo.image.width.toDouble();
                final imgH = imageInfo.image.height.toDouble();
                final boxW = constraints.maxWidth;
                final boxH = constraints.maxHeight;
                final scale = _calculateScale(imgW, imgH, boxW, boxH);
                final offset = _calculateOffset(imgW, imgH, boxW, boxH);

                return Stack(
                  children: [
                    Image.file(
                      imageFile,
                      width: boxW,
                      height: boxH,
                      fit: BoxFit.contain,
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BBoxPainter(
                          bboxes: detectedBboxes,
                          names: detectedNames,
                          scale: scale,
                          offset: offset,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Future<ImageInfo> _getImageInfo(File file) async {
  final completer = Completer<ImageInfo>();
  final image = Image.file(file);
  image.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) => completer.complete(info)),
      );
  return completer.future;
}

Offset _calculateOffset(double imgW, double imgH, double boxW, double boxH) {
  final scale = _calculateScale(imgW, imgH, boxW, boxH);
  final displayW = imgW * scale;
  final displayH = imgH * scale;
  return Offset((boxW - displayW) / 2, (boxH - displayH) / 2);
}

double _calculateScale(double imgW, double imgH, double boxW, double boxH) {
  final scaleW = boxW / imgW;
  final scaleH = boxH / imgH;
  return scaleW < scaleH ? scaleW : scaleH;
}

class _BBoxPainter extends CustomPainter {
  _BBoxPainter({
    required this.bboxes,
    required this.names,
    required this.scale,
    required this.offset,
  });

  final List<List<double>> bboxes;
  final List<String> names;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const textStyle = TextStyle(
      color: Colors.red,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    for (int index = 0; index < bboxes.length; index++) {
      final bbox = bboxes[index];
      if (bbox.length < 4) continue;

      final rect = Rect.fromLTRB(
        bbox[0] * scale + offset.dx,
        bbox[1] * scale + offset.dy,
        bbox[2] * scale + offset.dx,
        bbox[3] * scale + offset.dy,
      );
      canvas.drawRect(rect, paint);

      final name = index < names.length ? names[index] : '';
      final textPainter = TextPainter(
        text: TextSpan(text: name, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.top - textPainter.height - 4,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.top - textPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
