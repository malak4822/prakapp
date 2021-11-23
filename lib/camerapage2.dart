import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:body_detection/models/image_result.dart';
import 'package:body_detection/models/pose.dart';
import 'package:body_detection/models/body_mask.dart';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:body_detection/body_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pose_mask_painter.dart';

import 'dart:ui';

void main() {
  runApp(const SecCamPage());
}

class SecCamPage extends StatefulWidget {
  const SecCamPage({Key? key}) : super(key: key);

  @override
  State<SecCamPage> createState() => _SecCamPageState();
}

class ZdjResult {
  final Size rozm;

  ZdjResult({
    required this.rozm,
  });

  factory ZdjResult.fromMap(Map<dynamic, dynamic> map) => ZdjResult(
      rozm: map['width'] != 20 && map['height'] != 20
          ? Size(map['width'].toDouble(), map['height'].toDouble())
          : Size.zero);
}

class _SecCamPageState extends State<SecCamPage> {
  ui.Image? zdj;
  ui.Image? nic;

  bool _isAppleVis = false;
  int _selectedTabIndex = 0;

  bool _isDetectingPose = false;
  bool _isDetectingBodyMask = false;

  Pose? _detectedPose;
  ui.Image? _maskImage;
  Image? _cameraImage;
  Size _imageSize = Size.zero;
  Size zdjSize = Size.zero;

  Future<void> _startCameraStream() async {
    final request = await Permission.camera.request();
    if (request.isGranted) {
      await BodyDetection.startCameraStream(
        onFrameAvailable: _handleCameraImage,
        onPoseAvailable: (pose) {
          if (!_isDetectingPose) return;
          _handlePose(pose);
        },
        onMaskAvailable: (mask) {
          if (!_isDetectingBodyMask) return;
          _handleBodyMask(mask);
        },
      );
    }
  }

  Future<void> _stopCameraStream() async {
    await BodyDetection.stopCameraStream();

    setState(() {
      _cameraImage = null;
      _imageSize = Size.zero;
    });
  }

  void _handleCameraImage(ImageResult result) {
    // Ignore callback if navigated out of the page.
    if (!mounted) return;

    // To avoid a memory leak issue.
    // https://github.com/flutter/flutter/issues/60160
    PaintingBinding.instance?.imageCache?.clear();
    PaintingBinding.instance?.imageCache?.clearLiveImages();

    final image = Image.memory(
      result.bytes,
      gaplessPlayback: true,
      fit: BoxFit.fill,
    );

    setState(() {
      _cameraImage = image;
      _imageSize = result.size;
    });
  }

  void _handleZdjImage(ZdjResult rezultat) {
    // Ignore callback if navigated out of the page.

    // To avoid a memory leak issue.
    // https://github.com/flutter/flutter/issues/60160
    PaintingBinding.instance?.imageCache?.clear();
    PaintingBinding.instance?.imageCache?.clearLiveImages();

    setState(() {
      zdjSize = rezultat.rozm;
    });
  }

  void _handlePose(Pose? pose) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    setState(() {
      _detectedPose = pose;
    });
  }

  void _handleBodyMask(BodyMask? mask) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    if (mask == null) {
      setState(() {
        _maskImage = null;
      });
      return;
    }

    final bytes = mask.buffer
        .expand(
          (it) => [0, 0, 0, (it * 230).toInt()],
        )
        .toList();
    ui.decodeImageFromPixels(Uint8List.fromList(bytes), mask.width, mask.height,
        ui.PixelFormat.rgba8888, (image) {
      setState(() {
        _maskImage = image;
      });
    });
  }

  Future<void> _toggleDetectPose() async {
    if (_isDetectingPose) {
      await BodyDetection.disablePoseDetection();
    } else {
      await BodyDetection.enablePoseDetection();
    }

    setState(() {
      _isDetectingPose = !_isDetectingPose;
      _detectedPose = null;
    });
  }

  Future<void> _toggleDetectBodyMask() async {
    if (_isDetectingBodyMask) {
      await BodyDetection.disableBodyMaskDetection();
    } else {
      await BodyDetection.enableBodyMaskDetection();
    }

    setState(() {
      _isDetectingBodyMask = !_isDetectingBodyMask;
      _maskImage = null;
    });
  }

  void _onTabEnter(int index) {
    // Camera tab
    if (index == 1) {
      _startCameraStream();
    }
  }

  void _onTabExit(int index) {
    // Camera tab
    if (index == 1) {
      _stopCameraStream();
    }
  }

  void _onTabSelectTapped(int index) {
    _onTabExit(_selectedTabIndex);
    _onTabEnter(index);
    _startCameraStream();

    setState(() {
      _selectedTabIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();

    loadImage("img/apple.png");
  }

  Future loadImage(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    final zdj = await decodeImageFromList(bytes);

    setState(() => this.zdj = zdj);
  }

  Widget get _cameraDetectionView => SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: CustomPaint(
                  child: _cameraImage,
                  foregroundPainter: PoseMaskPainter(
                    zdj: _isAppleVis ? zdj : nic,
                    pose: _detectedPose,
                    mask: _maskImage,
                    imageSize: _imageSize,
                  ),
                ),
              ),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.white),
                  onPressed: () async {
                    _startCameraStream();
                  },
                  child: Text(
                    "Włącz kamerę",
                    style: GoogleFonts.overpass(
                        color: Colors.black, fontSize: 20.0),
                  )),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.white),
                  onPressed: () async {
                    _stopCameraStream();
                  },
                  child: Text(
                    "Wyłącz kamerę",
                    style: GoogleFonts.overpass(
                        color: Colors.black, fontSize: 20.0),
                  )),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.white),
                  onPressed: () async {
                    if (_isAppleVis == true) {
                      _isAppleVis = !_isAppleVis;
                    }
                    // _toggleDetectBodyMask();
                    _toggleDetectPose();
                  },
                  child: Text(
                    "Wyłącz / Wyłącz odk",
                    style: GoogleFonts.overpass(
                        color: Colors.black, fontSize: 20.0),
                  )),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white38,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _cameraDetectionView,
          ]),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                color: Colors.black12, height: 100.0, child: ListView()),
          )
        ]);
      }),
    );
  }
}
