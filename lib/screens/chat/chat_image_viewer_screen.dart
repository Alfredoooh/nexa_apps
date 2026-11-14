import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import 'chat_models.dart';

class AitabImageViewerScreen extends StatelessWidget {
  final AttachedFile file;
  final bool isImage;
  const AitabImageViewerScreen({
    super.key,
    required this.file,
    required this.isImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: isImage
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.memory(file.bytes, fit: BoxFit.contain),
                      )
                    : GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(RoundedSymbols.insertDriveFile,
                                  size: 48, color: Colors.white70),
                              const SizedBox(height: 14),
                              Text(
                                file.name,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon('close', color: Colors.white, size: 18),
                  ),
                ),
              ),
              if (isImage)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}