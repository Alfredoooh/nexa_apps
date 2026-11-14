import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'chat_models.dart';

import '../../widgets/widgets.dart';
class AitabCameraScreen extends StatefulWidget {
  const AitabCameraScreen({super.key});

  @override
  State<AitabCameraScreen> createState() => _AitabCameraScreenState();
}

class _AitabCameraScreenState extends State<AitabCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initController(_cameras[_cameraIndex]);
    }
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = 'Nenhuma câmera disponível neste dispositivo.';
          _initializing = false;
        });
        return;
      }
      // Preferir a câmera traseira por padrão.
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _initController(_cameras[_cameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível aceder à câmera.';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _initController(CameraDescription description) async {
    setState(() => _initializing = true);
    final previous = _controller;
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Falha ao inicializar a câmera.';
        });
      }
    }
    await previous?.dispose();
    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(
        AttachedFile(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: file.name,
          mimeType: 'image/jpeg',
          bytes: bytes,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildPreview()),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _TopBar(
                onClose: () => Navigator.of(context).pop(),
                onToggleFlash: _toggleFlash,
                flashOn: _flashMode != FlashMode.off,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: _BottomBar(
                onCapture: _capture,
                onSwitchCamera: _cameras.length > 1 ? _switchCamera : null,
                capturing: _capturing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }
    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final bool flashOn;
  const _TopBar({
    required this.onClose,
    required this.onToggleFlash,
    required this.flashOn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleGlassButton(
          icon: RoundedSymbols.close,
          onTap: onClose,
        ),
        _CircleGlassButton(
          icon: flashOn ? RoundedSymbols.flashOn : RoundedSymbols.flashOff,
          onTap: onToggleFlash,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback? onSwitchCamera;
  final bool capturing;
  const _BottomBar({
    required this.onCapture,
    required this.onSwitchCamera,
    required this.capturing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48, height: 48),
          _ShutterButton(onTap: capturing ? null : onCapture, busy: capturing),
          _CircleGlassButton(
            icon: RoundedSymbols.cameraSwitch,
            onTap: onSwitchCamera,
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool busy;
  const _ShutterButton({required this.onTap, required this.busy});

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
          ),
          child: widget.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CircleGlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleGlassButton({required this.icon, required this.onTap});

  @override
  State<_CircleGlassButton> createState() => _CircleGlassButtonState();
}

class _CircleGlassButtonState extends State<_CircleGlassButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _p = true) : null,
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(enabled ? 0.35 : 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withOpacity(enabled ? 1.0 : 0.4),
            size: 22,
          ),
        ),
      ),
    );
  }
}