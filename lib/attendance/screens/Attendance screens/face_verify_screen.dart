import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/api_config.dart';

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
  // Add this flag at the top of _FaceVerifyScreenState
  bool _captureInProgress = false;

  Future<void> _capture() async {
    // ✅ Guard — prevent multiple simultaneous calls
    if (_controller == null ||
        !_cameraReady ||
        _verifying ||
        _captureInProgress)
      return;

    _captureInProgress = true; // ← lock
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();

      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse(ApiConfig.face_url + '/compare'),
            )
            ..fields['emp_id'] = widget.employeeId.toString()
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: 'selfie.jpg',
                contentType: MediaType('image', 'jpeg'),
              ),
            );

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
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
    } finally {
      _captureInProgress = false; // ← always unlock
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
      backgroundColor: const Color(0xFF0B0F1C),
      body: Column(
        children: [
          // ── Camera zone (top) ──────────────────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_cameraReady && _controller != null)
                  _buildCameraPreview()
                else
                  _buildLoadingState(),
                _buildTopBar(),
                _buildFaceOverlay(),
                if (_verifying) _buildVerifyingOverlay(),
              ],
            ),
          ),
          // ── Controls panel (bottom) ────────────────────────────────────
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return Container(
      color: const Color(0xFF0F1525),
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(_controller!)),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFF0F1525),
      child: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF3B82F6),
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Starting camera...',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGradientOverlays() => const SizedBox.shrink();

  Widget _buildFaceOverlay() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final ovalW = w * 0.62;
        final ovalH = ovalW * 1.28;
        final left = (w - ovalW) / 2;
        final top = (h - ovalH) / 2 - 10;

        final borderColor = _error != null
            ? const Color(0xFFEF4444)
            : _verifying
            ? const Color(0xFF60A5FA)
            : const Color(0xFF3B82F6);

        return Stack(
          children: [
            // Dark mask with oval cutout
            ClipPath(
              clipper: _OvalCutoutClipper(
                ovalRect: Rect.fromLTWH(left, top, ovalW, ovalH),
              ),
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),

            // Oval border
            Positioned(
              left: left - 1,
              top: top - 1,
              child: Container(
                width: ovalW + 2,
                height: ovalH + 2,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 2),
                  borderRadius: BorderRadius.circular(ovalW / 2),
                ),
              ),
            ),

            // Corner accents
            ..._buildCornerAccents(left, top, ovalW, ovalH),

            // Scan line — only when idle
            if (!_verifying && _error == null)
              AnimatedBuilder(
                animation: _scanLine,
                builder: (_, __) {
                  final scanY = top + _scanLine.value * ovalH;
                  return Positioned(
                    left: left + 12,
                    top: scanY,
                    child: Container(
                      width: ovalW - 24,
                      height: 1.5,
                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                    ),
                  );
                },
              ),

            // Label below oval
            Positioned(
              left: 0,
              right: 0,
              top: top + ovalH + 16,
              child: Text(
                _verifying
                    ? 'Analyzing...'
                    : _error != null
                    ? 'No match — please retry'
                    : 'Align face within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error != null
                      ? const Color(0xFFFCA5A5)
                      : Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
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
    const len = 20.0;
    const thick = 2.5;
    final color = _error != null
        ? const Color(0xFFEF4444)
        : _verifying
        ? const Color(0xFF60A5FA)
        : const Color(0xFF3B82F6);

    final positions = [
      (left - 1, top - 1, true, true),
      (left + ovalW - len + 1, top - 1, false, true),
      (left - 1, top + ovalH - len + 1, true, false),
      (left + ovalW - len + 1, top + ovalH - len + 1, false, false),
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context, null),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Face verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Look straight at the camera',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: const Color(0xFF0B0F1C),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tip row
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 14,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Good lighting · Face forward · Remove glasses',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Status pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _error != null
                    ? const Color(0xFFEF4444).withOpacity(0.1)
                    : _verifying
                    ? const Color(0xFF3B82F6).withOpacity(0.1)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _error != null
                      ? const Color(0xFFEF4444).withOpacity(0.25)
                      : _verifying
                      ? const Color(0xFF3B82F6).withOpacity(0.25)
                      : Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  if (_verifying)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        color: Color(0xFF60A5FA),
                        strokeWidth: 1.5,
                      ),
                    )
                  else
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _error != null
                            ? const Color(0xFFF87171)
                            : Colors.white.withOpacity(0.25),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _verifying
                        ? 'Analyzing face...'
                        : _error != null
                        ? 'No match — please retry'
                        : 'Ready — tap capture to verify',
                    style: TextStyle(
                      color: _error != null
                          ? const Color(0xFFF87171)
                          : _verifying
                          ? const Color(0xFF93C5FD)
                          : Colors.white.withOpacity(0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Capture button
            Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: _cameraReady && !_verifying ? _capture : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _error != null
                              ? const Color(0xFF16A34A)
                              : _cameraReady && !_verifying
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF2563EB).withOpacity(0.4),
                        ),
                        child: Icon(
                          _error != null
                              ? Icons.refresh_rounded
                              : Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error != null
                      ? 'Tap to retry'
                      : _verifying
                      ? 'Verifying...'
                      : 'Tap to capture',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.25),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFF3B82F6),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verifying identity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Comparing with employee record',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF4ADE80),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Identity verified',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.confidence}% confidence match',
                  style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starting attendance tracking...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
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
