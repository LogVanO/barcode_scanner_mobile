import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart';

class BarcodeScannerWithScanWindow extends StatefulWidget {
  const BarcodeScannerWithScanWindow({super.key, required this.scanningMode});

  final Mode scanningMode;

  @override
  State<BarcodeScannerWithScanWindow> createState() =>
      _BarcodeScannerWithScanWindowState();
}

class _BarcodeScannerWithScanWindowState
    extends State<BarcodeScannerWithScanWindow> {
  late MobileScannerController controller = MobileScannerController();
  Barcode? barcode;
  BarcodeCapture? capture;
  bool captured = false;

  Future<void> onDetect(BarcodeCapture barcode) async {
    capture = barcode;
    setState(() => this.barcode = barcode.barcodes.first);

    if (widget.scanningMode == Mode.connecting && !captured) {
      captured = true;
      controller.stop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            // set to show barcode scan button instead of connect to pc button
            // set value of channel
            title: "Home", 
            connectedIp: (barcode.barcodes.first.displayValue ?? ""),
            connectedBool: true,
            ),
        ),
      );
    }

    if (widget.scanningMode == Mode.scanning && !captured) {
      captured = true;
      controller.stop();
      Navigator.pop(
        context,
        (barcode.barcodes.first.displayValue ?? "")
      );
    }
  }

  MobileScannerArguments? arguments;

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 200,
      height: 200,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR to connect to PC')),
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                fit: BoxFit.contain,
                scanWindow: scanWindow,
                controller: controller,
                onScannerStarted: (arguments) {
                  setState(() {
                    this.arguments = arguments;
                  });
                },
                onDetect: onDetect,
              ),
              if (barcode != null &&
                  barcode?.corners != null &&
                  arguments != null)
                CustomPaint(
                  painter: BarcodeOverlay(
                    barcode: barcode!,
                    arguments: arguments!,
                    boxFit: BoxFit.contain,
                    capture: capture!,
                  ),
                ),
              CustomPaint(
                painter: ScannerOverlay(scanWindow),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()..addRect(scanWindow);

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(backgroundWithCutout, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class BarcodeOverlay extends CustomPainter {
  BarcodeOverlay({
    required this.barcode,
    required this.arguments,
    required this.boxFit,
    required this.capture,
  });

  final BarcodeCapture capture;
  final Barcode barcode;
  final MobileScannerArguments arguments;
  final BoxFit boxFit;

  @override
  void paint(Canvas canvas, Size size) {
    if (barcode.corners.isEmpty) {
      return;
    }

    final adjustedSize = applyBoxFit(boxFit, arguments.size, size);

    double verticalPadding = size.height - adjustedSize.destination.height;
    double horizontalPadding = size.width - adjustedSize.destination.width;
    if (verticalPadding > 0) {
      verticalPadding = verticalPadding / 2;
    } else {
      verticalPadding = 0;
    }

    if (horizontalPadding > 0) {
      horizontalPadding = horizontalPadding / 2;
    } else {
      horizontalPadding = 0;
    }

    final double ratioWidth;
    final double ratioHeight;

    if (!kIsWeb && Platform.isIOS) {
      ratioWidth = capture.size.width / adjustedSize.destination.width;
      ratioHeight = capture.size.height / adjustedSize.destination.height;
    } else {
      ratioWidth = arguments.size.width / adjustedSize.destination.width;
      ratioHeight = arguments.size.height / adjustedSize.destination.height;
    }

    final List<Offset> adjustedOffset = [];
    for (final offset in barcode.corners) {
      adjustedOffset.add(
        Offset(
          offset.dx / ratioWidth + horizontalPadding,
          offset.dy / ratioHeight + verticalPadding,
        ),
      );
    }
    final cutoutPath = Path()..addPolygon(adjustedOffset, true);

    final backgroundPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    canvas.drawPath(cutoutPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

enum Mode {
  scanning,
  connecting;
}
