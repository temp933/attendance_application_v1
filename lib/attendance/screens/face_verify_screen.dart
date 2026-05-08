import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/api_config.dart';

/// Result returned after face verification attempt
class FaceVerifyResult {
  final bool match;
  final int confidence;
  final String reason;
  FaceVerifyResult({
    required this.match,
    required this.confidence,
    required this.reason,
  });
}

/// Full-screen face verification flow.
/// Usage:
///   final result = await Navigator.push<FaceVerifyResult>(
///     context,
///     MaterialPageRoute(builder: (_) => FaceVerifyScreen(employeeId: empId)),
///   );
///   if (result != null && result.match) { /* proceed */ }
class FaceVerifyScreen extends StatefulWidget {
  final int employeeId;
  const FaceVerifyScreen({super.key, required this.employeeId});

  @override
  State<FaceVerifyScreen> createState() => _FaceVerifyScreenState();
}

class _FaceVerifyScreenState extends State<FaceVerifyScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _verifying = false;
  String? _error;

  // Scanning animation
  late AnimationController _scanAnim;
  late Animation<double> _scanLine;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLine = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut));

    _pulseAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut));

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // prefer front camera
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ── Capture + verify ────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_controller == null || !_cameraReady || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      // Flash effect
      final xFile = await _controller!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();

      // POST to /attendance/verify-face
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiConfig.baseUrl}/attendance/verify-face'),
            )
            ..headers.addAll(ApiConfig.headers)
            ..fields['employee_id'] = widget.employeeId.toString()
            ..files.add(
              http.MultipartFile.fromBytes(
                'photo',
                bytes,
                filename: 'selfie.jpg',
                contentType: MediaType(
                  'image',
                  'jpeg',
                ), // ✅ explicit content type
              ),
            );

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (!mounted) return;

      final result = FaceVerifyResult(
        match: json['match'] == true,
        confidence: (json['confidence'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
      );

      if (result.match) {
        // Success — brief success overlay then pop
        setState(() => _verifying = false);
        await _showResult(result);
        if (mounted) Navigator.pop(context, result);
      } else {
        setState(() {
          _verifying = false;
          _error =
              'Face not matched (${result.confidence}% confidence)\n${result.reason}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = 'Verification failed: $e';
        });
      }
    }
  }

  Future<void> _showResult(FaceVerifyResult result) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessOverlay(confidence: result.confidence),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraReady && _controller != null)
            _buildCameraPreview()
          else
            _buildLoadingState(),

          // Dark gradient overlays (top + bottom)
          _buildGradientOverlays(),

          // Face oval cutout + scan line
          _buildFaceOverlay(),

          // Top bar
          _buildTopBar(),

          // Bottom controls
          _buildBottomControls(),

          // Verifying overlay
          if (_verifying) _buildVerifyingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(child: CameraPreview(_controller!)),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: _error != null
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Starting camera...',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
    );
  }

  Widget _buildGradientOverlays() {
    return Column(
      children: [
        // Top gradient
        Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.85), Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        // Bottom gradient
        Container(
          height: 260,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.9), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceOverlay() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final ovalW = w * 0.68;
        final ovalH = ovalW * 1.28;
        final left = (w - ovalW) / 2;
        final top = (h - ovalH) / 2 - 20;

        return Stack(
          children: [
            // Dark mask with oval cutout
            ClipPath(
              clipper: _OvalCutoutClipper(
                ovalRect: Rect.fromLTWH(left, top, ovalW, ovalH),
              ),
              child: Container(color: Colors.black.withOpacity(0.52)),
            ),

            // Oval border (animated pulse)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, _) {
                return Positioned(
                  left: left - 2,
                  top: top - 2,
                  child: Transform.scale(
                    scale: _verifying ? 1.0 : _pulseAnim.value,
                    child: Container(
                      width: ovalW + 4,
                      height: ovalH + 4,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _error != null
                              ? Colors.red.shade400
                              : _verifying
                              ? Colors.blue.shade300
                              : const Color(0xFF00E5FF),
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(ovalW / 2),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Corner accents
            ..._buildCornerAccents(left, top, ovalW, ovalH),

            // Scan line (only when not verifying and no error)
            if (!_verifying && _error == null)
              AnimatedBuilder(
                animation: _scanLine,
                builder: (_, _) {
                  final scanY = top + _scanLine.value * ovalH;
                  return Positioned(
                    left: left + 10,
                    top: scanY,
                    child: Container(
                      width: ovalW - 20,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF00E5FF).withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Status text below oval
            Positioned(
              left: 0,
              right: 0,
              top: top + ovalH + 20,
              child: Column(
                children: [
                  Text(
                    _error != null
                        ? '✗ Verification Failed'
                        : _verifying
                        ? 'Analyzing...'
                        : 'Position your face in the oval',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _error != null
                          ? Colors.red.shade300
                          : _verifying
                          ? Colors.blue.shade200
                          : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCornerAccents(
    double left,
    double top,
    double ovalW,
    double ovalH,
  ) {
    const len = 22.0;
    const thick = 3.0;
    final color = _error != null
        ? Colors.red.shade400
        : const Color(0xFF00E5FF);

    // We'll place accents at the 4 "corners" of the oval bounding box
    final positions = [
      // top-left
      (left, top, true, true),
      // top-right
      (left + ovalW - len, top, false, true),
      // bottom-left
      (left, top + ovalH - len, true, false),
      // bottom-right
      (left + ovalW - len, top + ovalH - len, false, false),
    ];

    return positions.map((p) {
      final (x, y, isLeft, isTop) = p;
      return Positioned(
        left: x,
        top: y,
        child: SizedBox(
          width: len,
          height: len,
          child: CustomPaint(
            painter: _CornerPainter(
              color: color,
              thickness: thick,
              isLeft: isLeft,
              isTop: isTop,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context, null),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Face Verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'Verify your identity to start tracking',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tips
              if (!_verifying) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 14,
                        color: Colors.amber.shade300,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ensure good lighting · Look straight at camera',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Capture button
              GestureDetector(
                onTap: _cameraReady && !_verifying ? _capture : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error != null
                        ? Colors.red.withOpacity(0.9)
                        : _cameraReady && !_verifying
                        ? Colors.white
                        : Colors.white38,
                    boxShadow: _cameraReady && !_verifying
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    _error != null
                        ? Icons.refresh_rounded
                        : Icons.camera_alt_rounded,
                    color: _error != null ? Colors.white : Colors.black87,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error != null ? 'Tap to retry' : 'Tap to capture',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00E5FF),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verifying Identity...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Comparing with employee record',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Success overlay dialog ─────────────────────────────────────────────────────

class _SuccessOverlay extends StatefulWidget {
  final int confidence;
  const _SuccessOverlay({required this.confidence});

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // Auto-dismiss after 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2744),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.green.shade400.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade700.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.15),
                    border: Border.all(color: Colors.green.shade400, width: 2),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: Colors.green.shade400,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Identity Verified!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.confidence}% confidence match',
                  style: TextStyle(color: Colors.green.shade300, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starting attendance tracking...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom painters ───────────────────────────────────────────────────────────

class _OvalCutoutClipper extends CustomClipper<Path> {
  final Rect ovalRect;
  const _OvalCutoutClipper({required this.ovalRect});

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_OvalCutoutClipper old) => old.ovalRect != ovalRect;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isLeft;
  final bool isTop;

  const _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isLeft,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isLeft && isTop) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (!isLeft && isTop) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (isLeft && !isTop) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
