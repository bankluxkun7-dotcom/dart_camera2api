import 'dart:io';
import 'package:flutter/material.dart';

import 'dart:async';

class TestOverlay extends StatelessWidget {
	final File imageFile;
	final List<String> detectedNames;
	final List<List<double>> detectedBboxes;

	const TestOverlay({
		Key? key,
		required this.imageFile,
		required this.detectedNames,
		required this.detectedBboxes,
	}) : super(key: key);

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
								// คำนวณ scale
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
	final img = Image.file(file);
	img.image.resolve(const ImageConfiguration()).addListener(
		ImageStreamListener((info, _) => completer.complete(info)),
	);
	return completer.future;
}

Offset _calculateOffset(double imgW, double imgH, double boxW, double boxH) {
	final scale = _calculateScale(imgW, imgH, boxW, boxH);
	final displayW = imgW * scale;
	final displayH = imgH * scale;
	final dx = (boxW - displayW) / 2;
	final dy = (boxH - displayH) / 2;
	return Offset(dx, dy);
}

double _calculateScale(double imgW, double imgH, double boxW, double boxH) {
	final scaleW = boxW / imgW;
	final scaleH = boxH / imgH;
	return scaleW < scaleH ? scaleW : scaleH;
}

class _BBoxPainter extends CustomPainter {
	final List<List<double>> bboxes;
	final List<String> names;
	final double scale;
	final Offset offset;

	_BBoxPainter({required this.bboxes, required this.names, required this.scale, required this.offset});

	@override
	void paint(Canvas canvas, Size size) {
		final paint = Paint()
			..color = Colors.red
			..strokeWidth = 3
			..style = PaintingStyle.stroke;
		final textStyle = TextStyle(
			color: Colors.red,
			fontSize: 16,
			fontWeight: FontWeight.bold,
		);
		for (int i = 0; i < bboxes.length; i++) {
			final bbox = bboxes[i];
			if (bbox.length < 4) continue;
			final left = bbox[0] * scale + offset.dx;
			final top = bbox[1] * scale + offset.dy;
			final right = bbox[2] * scale + offset.dx;
			final bottom = bbox[3] * scale + offset.dy;
			final rect = Rect.fromLTRB(left, top, right, bottom);
			canvas.drawRect(rect, paint);
			final name = i < names.length ? names[i] : '';
			final tp = TextPainter(
				text: TextSpan(text: name, style: textStyle),
				textDirection: TextDirection.ltr,
			);
			tp.layout();
			canvas.drawRect(
				Rect.fromLTWH(rect.left, rect.top - tp.height - 4, tp.width + 8, tp.height + 4),
				Paint()..color = Colors.white.withOpacity(0.7),
			);
			tp.paint(canvas, Offset(rect.left + 4, rect.top - tp.height));
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
