import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Полноэкранный просмотр фото товара с pinch-to-zoom (как на WB).
class ProductImageGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ProductImageGalleryViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    if (imageUrls.isEmpty) return Future.value();
    final safeIndex = initialIndex.clamp(0, imageUrls.length - 1);
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ProductImageGalleryViewer(
          imageUrls: imageUrls,
          initialIndex: safeIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ProductImageGalleryViewer> createState() =>
      _ProductImageGalleryViewerState();
}

class _ProductImageGalleryViewerState extends State<ProductImageGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _pagingEnabled = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _pagingEnabled
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: total,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _ZoomableImage(
                imageUrl: widget.imageUrls[index],
                onScaleChanged: (scale) {
                  final enablePaging = scale <= 1.05;
                  if (enablePaging != _pagingEnabled) {
                    setState(() => _pagingEnabled = enablePaging);
                  }
                },
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                  const Spacer(),
                  if (total > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String imageUrl;
  final ValueChanged<double> onScaleChanged;

  const _ZoomableImage({
    required this.imageUrl,
    required this.onScaleChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_animation != null) {
          _transform.value = _animation!.value;
        }
      });
    _transform.addListener(_notifyScale);
  }

  @override
  void dispose() {
    _transform.removeListener(_notifyScale);
    _animationController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _notifyScale() {
    final scale = _transform.value.getMaxScaleOnAxis();
    widget.onScaleChanged(scale);
  }

  void _onDoubleTap() {
    final currentScale = _transform.value.getMaxScaleOnAxis();
    final end = currentScale > 1.05
        ? Matrix4.identity()
        : _zoomAt(_doubleTapDetails?.localPosition ?? Offset.zero);

    _animation = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0);
  }

  Matrix4 _zoomAt(Offset focalPoint) {
    final x = -focalPoint.dx * (_doubleTapScale - 1);
    final y = -focalPoint.dy * (_doubleTapScale - 1);
    return Matrix4.identity()
      ..translate(x, y)
      ..scale(_doubleTapScale);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: _minScale,
        maxScale: _maxScale,
        panEnabled: true,
        scaleEnabled: true,
        clipBehavior: Clip.none,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
