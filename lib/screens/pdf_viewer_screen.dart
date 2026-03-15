import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/screens/review_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/services/url_service.dart';
import 'package:purchaser_edge/utils/pdf_thumbnail_cache.dart';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:unicons/unicons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global Thumbnail Render Queue
// ─────────────────────────────────────────────────────────────────────────────
class _ThumbnailRenderQueue {
  static final _ThumbnailRenderQueue _instance =
      _ThumbnailRenderQueue._internal();
  factory _ThumbnailRenderQueue() => _instance;
  _ThumbnailRenderQueue._internal();

  final Map<String, Future<void>> _fileLocks = {};
  int _activeCount = 0;
  static const int _maxConcurrent = 2;
  final List<Completer<void>> _waitQueue = [];

  Future<Uint8List?> render({
    required String filePath,
    required int pageNumber,
    required int rotation,
  }) async {
    while (_activeCount >= _maxConcurrent) {
      final c = Completer<void>();
      _waitQueue.add(c);
      await c.future;
    }
    _activeCount++;

    try {
      final prev = _fileLocks[filePath] ?? Future.value();
      final myCompleter = Completer<void>();
      _fileLocks[filePath] = myCompleter.future;

      Uint8List? result;
      try {
        await prev;
        result = await _doRender(filePath, pageNumber, rotation);
      } finally {
        myCompleter.complete();
        if (_fileLocks[filePath] == myCompleter.future) {
          _fileLocks.remove(filePath);
        }
      }
      return result;
    } finally {
      _activeCount--;
      if (_waitQueue.isNotEmpty) {
        _waitQueue.removeAt(0).complete();
      }
    }
  }

  Future<Uint8List?> _doRender(
      String filePath, int pageNumber, int rotation) async {
    pdfrx.PdfDocument? document;
    try {
      document = await pdfrx.PdfDocument.openFile(filePath);
      final int totalPages = document.pages.length;
      if (pageNumber < 1 || pageNumber > totalPages) return null;

      final page = document.pages[pageNumber - 1];
      const double targetLong = 1200.0;
      final double scale = page.width >= page.height
          ? targetLong / page.width
          : targetLong / page.height;
      final int imgW = (page.width * scale).round().clamp(1, 1200);
      final int imgH = (page.height * scale).round().clamp(1, 1200);

      final pdfrx.PdfImage? pageImage = await page.render(
        fullWidth: imgW.toDouble(),
        fullHeight: imgH.toDouble(),
      );
      if (pageImage == null) return null;

      final Uint8List pixelsCopy = Uint8List.fromList(pageImage.pixels);
      final int pw = pageImage.width;
      final int ph = pageImage.height;

      document.dispose();
      document = null;

      final buffer = await ui.ImmutableBuffer.fromUint8List(pixelsCopy);
      final descriptor = await ui.ImageDescriptor.raw(
        buffer,
        width: pw,
        height: ph,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frameInfo = await codec.getNextFrame();
      final byteData =
          await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
      frameInfo.image.dispose();
      codec.dispose();

      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      return rotation == 0 ? pngBytes : await _rotateImage(pngBytes, rotation);
    } catch (e) {
      debugPrint('[Thumbnail] error page=$pageNumber: $e');
      return null;
    } finally {
      document?.dispose();
    }
  }

  Future<Uint8List> _rotateImage(Uint8List src, int rotation) async {
    final codec = await ui.instantiateImageCodec(src);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    codec.dispose();

    final int w = img.width;
    final int h = img.height;
    final bool swap = rotation == 90 || rotation == 270;
    final int cw = swap ? h : w;
    final int ch = swap ? w : h;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(cw / 2, ch / 2);
    canvas.rotate(rotation * 3.141592653589793 / 180.0);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawImage(img, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final rotated = await picture.toImage(cw, ch);
    img.dispose();

    final bd = await rotated.toByteData(format: ui.ImageByteFormat.png);
    rotated.dispose();
    return bd!.buffer.asUint8List();
  }
}

final _thumbnailQueue = _ThumbnailRenderQueue();

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class ReviewDocumentData {
  final List<PageInfo> pages;
  final Map<int, int> pageRotations;
  final Map<int, List<SignatureInfo>> pageSignatures;

  const ReviewDocumentData({
    required this.pages,
    required this.pageRotations,
    required this.pageSignatures,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PdfViewerScreen
// ─────────────────────────────────────────────────────────────────────────────
class PdfViewerScreen extends StatefulWidget {
  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  List<PdfFileInfo> pdfFiles = [];
  List<PageInfo> allPages = [];
  String? mergedFilePath;
  int? selectedPageIndex;
  Map<int, List<SignatureInfo>> pageSignatures = {};
  Map<int, int> pageRotations = {};
  final ScrollController _previewScrollController = ScrollController();
  final ScrollController _thumbnailScrollController = ScrollController();
  final Map<int, GlobalKey> _pageKeys = {};
  final Map<int, GlobalKey> _thumbnailKeys = {};
  final Map<String, Size> _pageSizeCache = {};

  List<String> _loadedFilePaths = [];
  late FileProvider _fileProvider;
  bool _isListenerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fileProvider = context.read<FileProvider>();
        _fileProvider.addListener(_onProviderChanged);
        _isListenerAttached = true;
        _syncFromProvider();
      }
    });
  }

  void _onProviderChanged() {
    if (mounted) _syncFromProvider();
  }

  Future<void> _syncFromProvider() async {
    if (!mounted) return;
    final providerFiles = _fileProvider.files;
    final newIds = providerFiles.map((f) => f.id).toList();
    if (_listEquals(newIds, _loadedFilePaths)) return;
    _loadedFilePaths = List.from(newIds);
    await _loadFilesFromProvider(providerFiles.map((f) => f.file).toList());
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadFilesFromProvider(List<File> files) async {
    if (!mounted) return;
    if (files.isEmpty) {
      setState(() {
        pdfFiles.clear();
        rebuildAllPages();
        mergedFilePath = null;
      });
      return;
    }

    List<PdfFileInfo> loaded = [];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final doc = PdfDocument(inputBytes: bytes);
        loaded.add(PdfFileInfo(
          filePath: file.path,
          fileName: file.path.split('/').last,
          pageCount: doc.pages.count,
        ));
        doc.dispose();
      } catch (e) {
        debugPrint('Error loading ${file.path}: $e');
      }
    }

    if (mounted) {
      setState(() {
        pdfFiles = loaded;
        rebuildAllPages();
        mergedFilePath = null;
      });
    }
  }

  @override
  void dispose() {
    if (_isListenerAttached) {
      try {
        _fileProvider.removeListener(_onProviderChanged);
        _isListenerAttached = false;
      } catch (e) {
        debugPrint('Error removing listener: $e');
      }
    }
    _previewScrollController.dispose();
    _thumbnailScrollController.dispose();
    _pageSizeCache.clear();
    pdfThumbnailCache.clear();
    super.dispose();
  }

  void _navigateToReview() {
    if (pdfFiles.isEmpty) return;

    final Map<int, List<SignatureInfo>> copiedSignatures = {};
    pageSignatures.forEach((key, sigs) {
      copiedSignatures[key] = sigs
          .map((s) => SignatureInfo(
                imageBytes: Uint8List.fromList(s.imageBytes),
                left: s.left,
                top: s.top,
                width: s.width,
                height: s.height,
                pageIndex: s.pageIndex,
              ))
          .toList();
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          documentData: ReviewDocumentData(
            pages: List.from(allPages),
            pageRotations: Map.from(pageRotations),
            pageSignatures: copiedSignatures,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: ColorService().mainGredientColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back
                GestureDetector(
                  onTap: () => Future.microtask(
                      () => mounted ? Navigator.pop(context) : null),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(UniconsLine.arrow_left,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ກັບຄືນ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Title
                const Text(
                  'ກວດສອບ ແລະ ເຊັນເອກະສານ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // Right buttons
                Row(
                  children: [
                    if (selectedPageIndex != null) ...[
                      GestureDetector(
                        onTap: () {
                          pickSignatureFromUrl(
                            UrlService().baseUrl +
                                '/signature/${context.read<AuthProvider>().currentUser!.fileSignature}',
                          );
                        },
                        child: Container(
                          height: 38,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.edit_road,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'ເພີ່ມລາຍເຊັນ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    GestureDetector(
                      onTap: _navigateToReview,
                      child: Container(
                        height: 38,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: pdfFiles.isEmpty
                              ? Colors.white.withOpacity(0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: pdfFiles.isEmpty
                              ? []
                              : [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              UniconsLine.sign_out_alt,
                              size: 16,
                              color: pdfFiles.isEmpty
                                  ? Colors.white.withOpacity(0.5)
                                  : ColorService().primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ດຳເນີນການຕໍ່',
                              style: TextStyle(
                                color: pdfFiles.isEmpty
                                    ? Colors.white.withOpacity(0.5)
                                    : ColorService().primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // ── Sidebar ──────────────────────────────────────
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right:
                          BorderSide(color: Colors.grey.shade200),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Sidebar header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: ColorService()
                                    .primaryColor
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                UniconsLine.layers,
                                size: 14,
                                color: ColorService().primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ໜ້າທັງໝົດ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ColorService().mainTextColor,
                              ),
                            ),
                            const Spacer(),
                            if (allPages.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ColorService()
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${allPages.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: ColorService().primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: pdfFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 24,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'ຍັງບໍ່ມີເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ReorderableListView.builder(
                                scrollController:
                                    _thumbnailScrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                itemCount: getAllPages().length,
                                onReorder: _onReorder,
                                itemBuilder: _buildThumbnailItem,
                              ),
                      ),
                    ],
                  ),
                ),

                // ── Preview ──────────────────────────────────────
                Expanded(
                  child: pdfFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 36,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ບໍ່ມີເອກະສານ',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Center(
                            child: selectedPageIndex != null
                                ? SinglePagePreview(
                                    pageInfo: getAllPages()[
                                        selectedPageIndex!],
                                    pageIndex: selectedPageIndex!,
                                    rotation: pageRotations[
                                            selectedPageIndex!] ??
                                        0,
                                    signatures: pageSignatures[
                                            selectedPageIndex!] ??
                                        [],
                                    onSignatureUpdate: (idx, s) {
                                      setState(() {
                                        pageSignatures[selectedPageIndex!]![
                                            idx] = s;
                                      });
                                    },
                                    onSignatureDelete: (idx) {
                                      setState(() {
                                        pageSignatures[selectedPageIndex!]!
                                            .removeAt(idx);
                                        if (pageSignatures[
                                                selectedPageIndex!]!
                                            .isEmpty) {
                                          pageSignatures.remove(
                                              selectedPageIndex!);
                                        }
                                      });
                                    },
                                  )
                                : Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.touch_app,
                                          size: 32,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'ກົດເລືອກໜ້າຈາກດ້ານຊ້າຍ',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'ເພື່ອກວດສອບ ຫຼື ເພີ່ມລາຍເຊັນ',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final page = allPages.removeAt(oldIndex);
      allPages.insert(newIndex, page);
      _pageKeys.clear();
      _thumbnailKeys.clear();
      for (int i = 0; i < allPages.length; i++) {
        _pageKeys[i] = GlobalKey();
        _thumbnailKeys[i] = GlobalKey();
      }

      int remap(int key) {
        if (key == oldIndex) return newIndex;
        if (oldIndex < newIndex && key > oldIndex && key <= newIndex)
          return key - 1;
        if (oldIndex > newIndex && key >= newIndex && key < oldIndex)
          return key + 1;
        return key;
      }

      final ns = <int, List<SignatureInfo>>{};
      pageSignatures.forEach((k, v) {
        final nk = remap(k);
        ns[nk] = v
            .map((s) => SignatureInfo(
                  imageBytes: s.imageBytes,
                  left: s.left,
                  top: s.top,
                  width: s.width,
                  height: s.height,
                  pageIndex: nk,
                ))
            .toList();
      });
      pageSignatures = ns;

      final nr = <int, int>{};
      pageRotations.forEach((k, v) => nr[remap(k)] = v);
      pageRotations = nr;

      if (selectedPageIndex != null) {
        selectedPageIndex = remap(selectedPageIndex!);
      }
    });
  }

  Widget _buildThumbnailItem(BuildContext context, int index) {
    final pageInfo = getAllPages()[index];
    final bool isSelected = selectedPageIndex == index;
    final bool hasSignature = pageSignatures.containsKey(index) &&
        pageSignatures[index]!.isNotEmpty;

    return GestureDetector(
      key: ValueKey('${pageInfo.filePath}_${pageInfo.pageNumber}'),
      onTap: () => setState(() => selectedPageIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        key: _thumbnailKeys[index],
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? ColorService().primaryColor
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? ColorService().primaryColor.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? ColorService().primaryColor.withOpacity(0.05)
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.drag_handle,
                          color: Colors.grey.shade400, size: 18),
                      if (hasSignature) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: ColorService()
                                .primaryColor
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.edit,
                                  color: ColorService().primaryColor,
                                  size: 10),
                              const SizedBox(width: 2),
                              Text(
                                '${pageSignatures[index]!.length}',
                                style: TextStyle(
                                  color: ColorService().primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      // Rotate
                      InkWell(
                        onTap: () => setState(() {
                          pageRotations[index] =
                              ((pageRotations[index] ?? 0) + 90) % 360;
                        }),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.rotate_right,
                              color: Colors.blue.shade400, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete
                      InkWell(
                        onTap: () => setState(() {
                          if (selectedPageIndex == index) {
                            selectedPageIndex = null;
                          } else if (selectedPageIndex != null &&
                              selectedPageIndex! > index) {
                            selectedPageIndex = selectedPageIndex! - 1;
                          }
                          allPages.removeAt(index);
                          pageSignatures.remove(index);
                          pageRotations.remove(index);

                          final us = <int, List<SignatureInfo>>{};
                          pageSignatures.forEach((k, v) =>
                              us[k > index ? k - 1 : k] = v);
                          pageSignatures = us;

                          final ur = <int, int>{};
                          pageRotations.forEach((k, v) =>
                              ur[k > index ? k - 1 : k] = v);
                          pageRotations = ur;

                          _pageKeys.remove(index);
                          _thumbnailKeys.remove(index);
                          _pageSizeCache.remove(
                              '${pageInfo.filePath}_${pageInfo.pageNumber}');
                        }),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.delete_outline,
                              color: Colors.red.shade400, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Thumbnail
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: OptimizedPdfThumbnail(
                  filePath: pageInfo.filePath,
                  pageNumber: pageInfo.pageNumber,
                  rotation: pageRotations[index] ?? 0,
                ),
              ),
            ),

            // Label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? ColorService().primaryColor.withOpacity(0.05)
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9)),
              ),
              child: Text(
                'ໜ້າ ${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? ColorService().primaryColor
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int getTotalPages() => pdfFiles.fold(0, (s, f) => s + f.pageCount);
  List<PageInfo> getAllPages() => allPages;

  void rebuildAllPages() {
    allPages.clear();
    _pageKeys.clear();
    _thumbnailKeys.clear();
    pageRotations.clear();
    pageSignatures.clear();
    selectedPageIndex = null;
    _pageSizeCache.clear();
    int index = 0;
    for (var file in pdfFiles) {
      for (int i = 1; i <= file.pageCount; i++) {
        allPages.add(PageInfo(
          filePath: file.filePath,
          fileName: file.fileName,
          pageNumber: i,
          totalPages: file.pageCount,
        ));
        _pageKeys[index] = GlobalKey();
        _thumbnailKeys[index] = GlobalKey();
        index++;
      }
    }
  }

  Future<Size> getPageSizeCached(String filePath, int pageNumber) async {
    final key = '${filePath}_$pageNumber';
    if (_pageSizeCache.containsKey(key)) return _pageSizeCache[key]!;
    final bytes = await File(filePath).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final size = doc.pages[pageNumber - 1].size;
    doc.dispose();
    _pageSizeCache[key] = size;
    return size;
  }

  Future<void> pickSignatureFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final bytes = response.bodyBytes;
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: 800);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final compressedBytes = byteData!.buffer.asUint8List();
      final double ar = image.width / image.height;

      if (selectedPageIndex != null && mounted) {
        final pageInfo = getAllPages()[selectedPageIndex!];
        final originalSize = await getPageSizeCached(
            pageInfo.filePath, pageInfo.pageNumber);
        final rotation = pageRotations[selectedPageIndex!] ?? 0;

        Size rotatedSize = originalSize;
        if (rotation == 90 || rotation == 270) {
          rotatedSize = Size(originalSize.height, originalSize.width);
        }

        final double sigWidth = rotatedSize.width > rotatedSize.height
            ? 3.0 / 29.7
            : 3.0 / 21.0;

        setState(() {
          pageSignatures.putIfAbsent(selectedPageIndex!, () => []);
          pageSignatures[selectedPageIndex!]!.add(SignatureInfo(
            imageBytes: compressedBytes,
            left: 0.05,
            top: 0.85,
            width: sigWidth,
            height: sigWidth / ar,
            pageIndex: selectedPageIndex!,
          ));
        });
      }
      image.dispose();
    } catch (e) {
      debugPrint('Failed to load signature from URL: $e');
    }
  }

  Future<Uint8List> mergeFromPages(List<PageInfo> pages) async {
    List<Uint8List> pageBytesList = [];

    for (int i = 0; i < pages.length; i++) {
      final pageInfo = pages[i];
      final bytes = await File(pageInfo.filePath).readAsBytes();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      final sourcePage = loadedDoc.pages[pageInfo.pageNumber - 1];
      final Size orig = sourcePage.size;
      final int rot = pageRotations[i] ?? 0;

      final bool needsSwap = rot == 90 || rot == 270;
      final double rW = needsSwap ? orig.height : orig.width;
      final double rH = needsSwap ? orig.width : orig.height;

      final PdfDocument singleDoc = PdfDocument();
      singleDoc.pageSettings.margins.all = 0;
      singleDoc.pageSettings.size = Size(rW, rH);
      singleDoc.pageSettings.orientation = rW > rH
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final PdfPage newPage = singleDoc.pages.add();
      final Size a = newPage.size;
      final PdfTemplate tmpl = sourcePage.createTemplate();
      newPage.graphics.save();

      switch (rot) {
        case 0:
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
        case 90:
          newPage.graphics.translateTransform(a.width, 0);
          newPage.graphics.rotateTransform(90);
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
        case 180:
          newPage.graphics.translateTransform(a.width, a.height);
          newPage.graphics.rotateTransform(180);
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
        case 270:
          newPage.graphics.translateTransform(0, a.height);
          newPage.graphics.rotateTransform(-90);
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
      }
      newPage.graphics.restore();

      if (pageSignatures.containsKey(i)) {
        for (final sig in pageSignatures[i]!) {
          final bool wasFlipped = (a.width - rW).abs() > 1.0;
          double sl, st, sw, sh;
          if (!wasFlipped) {
            sl = sig.left * a.width;
            st = sig.top * a.height;
            sw = sig.width * a.width;
            sh = sig.height * a.height;
          } else {
            sl = sig.top * a.width;
            st = sig.left * a.height;
            sw = sig.height * a.width;
            sh = sig.width * a.height;
          }
          newPage.graphics.drawImage(
              PdfBitmap(sig.imageBytes), Rect.fromLTWH(sl, st, sw, sh));
        }
      }

      final singleBytes = await singleDoc.save();
      pageBytesList.add(Uint8List.fromList(singleBytes));
      singleDoc.dispose();
      loadedDoc.dispose();
    }

    if (pageBytesList.isEmpty) return Uint8List(0);
    if (pageBytesList.length == 1) return pageBytesList.first;

    final PdfDocument mergedDoc = PdfDocument();
    for (final pb in pageBytesList) {
      final srcDoc = PdfDocument(inputBytes: pb);
      final srcPage = srcDoc.pages[0];
      final srcSize = srcPage.size;

      mergedDoc.pageSettings.margins.all = 0;
      mergedDoc.pageSettings.size = srcSize;
      mergedDoc.pageSettings.orientation = srcSize.width > srcSize.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final destPage = mergedDoc.pages.add();
      final da = destPage.size;
      final srcTmpl = srcPage.createTemplate();

      if ((da.width - srcSize.width).abs() < 1.0) {
        destPage.graphics.drawPdfTemplate(srcTmpl, Offset.zero, srcSize);
      } else {
        destPage.graphics.save();
        destPage.graphics.translateTransform(da.width, 0);
        destPage.graphics.rotateTransform(90);
        destPage.graphics.drawPdfTemplate(srcTmpl, Offset.zero, srcSize);
        destPage.graphics.restore();
      }
      srcDoc.dispose();
    }

    final mergedBytes = await mergedDoc.save();
    mergedDoc.dispose();
    return Uint8List.fromList(mergedBytes);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OptimizedPdfThumbnail — ไม่แก้ logic เลย
// ─────────────────────────────────────────────────────────────────────────────
class OptimizedPdfThumbnail extends StatefulWidget {
  final String filePath;
  final int pageNumber;
  final int rotation;

  const OptimizedPdfThumbnail({
    Key? key,
    required this.filePath,
    required this.pageNumber,
    required this.rotation,
  }) : super(key: key);

  @override
  State<OptimizedPdfThumbnail> createState() =>
      _OptimizedPdfThumbnailState();
}

class _OptimizedPdfThumbnailState extends State<OptimizedPdfThumbnail> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(OptimizedPdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.rotation != widget.rotation) {
      _loadGeneration++;
      _startLoad();
    }
  }

  String get _cacheKey =>
      '${widget.filePath}_${widget.pageNumber}_${widget.rotation}';

  void _startLoad() {
    if (mounted) setState(() { _isLoading = true; _hasError = false; });
    _loadWithRetry();
  }

  Future<void> _loadWithRetry() async {
    final int myGen = _loadGeneration;

    if (pdfThumbnailCache.containsKey(_cacheKey)) {
      if (!mounted || myGen != _loadGeneration) return;
      setState(() {
        _imageBytes = pdfThumbnailCache[_cacheKey];
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    const delays = [0, 400, 1000, 2000];
    for (int attempt = 0; attempt < delays.length; attempt++) {
      if (!mounted || myGen != _loadGeneration) return;
      if (delays[attempt] > 0) {
        await Future.delayed(Duration(milliseconds: delays[attempt]));
        if (!mounted || myGen != _loadGeneration) return;
      }

      try {
        final result = await _thumbnailQueue.render(
          filePath: widget.filePath,
          pageNumber: widget.pageNumber,
          rotation: widget.rotation,
        );
        if (!mounted || myGen != _loadGeneration) return;
        if (result != null) {
          pdfThumbnailCache[_cacheKey] = result;
          setState(() { _imageBytes = result; _isLoading = false; _hasError = false; });
          return;
        }
      } catch (e) {
        debugPrint('[Thumbnail] attempt ${attempt + 1} threw: $e');
      }
    }

    if (!mounted || myGen != _loadGeneration) return;
    setState(() { _isLoading = false; _hasError = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || _imageBytes == null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined,
                  color: Colors.grey.shade400, size: 28),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () { _loadGeneration++; _startLoad(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 12, color: Colors.blue.shade400),
                      const SizedBox(width: 4),
                      Text('ລອງໃໝ່',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade400)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.memory(
        _imageBytes!,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SinglePagePreview, OptimizedPdfPreview, SignatureOverlay — ไม่แก้เลย
// ─────────────────────────────────────────────────────────────────────────────
class SinglePagePreview extends StatelessWidget {
  final PageInfo pageInfo;
  final int pageIndex;
  final int rotation;
  final List<SignatureInfo> signatures;
  final Function(int, SignatureInfo) onSignatureUpdate;
  final Function(int) onSignatureDelete;

  const SinglePagePreview({
    Key? key,
    required this.pageInfo,
    required this.pageIndex,
    required this.rotation,
    required this.signatures,
    required this.onSignatureUpdate,
    required this.onSignatureDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getPageSize(pageInfo.filePath, pageInfo.pageNumber),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        Size ps = snapshot.data!;
        double fw = rotation == 90 || rotation == 270 ? ps.height : ps.width;
        double fh = rotation == 90 || rotation == 270 ? ps.width : ps.height;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: AspectRatio(
              aspectRatio: fw / fh,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: fw,
                            height: fh,
                            child: OptimizedPdfPreview(
                              filePath: pageInfo.filePath,
                              pageNumber: pageInfo.pageNumber,
                              rotation: rotation,
                            ),
                          ),
                        ),
                      ),
                      ...signatures.asMap().entries.map((e) =>
                          SignatureOverlay(
                            signature: e.value,
                            rotation: rotation,
                            onUpdate: (s) => onSignatureUpdate(e.key, s),
                            onDelete: () => onSignatureDelete(e.key),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Size> _getPageSize(String filePath, int pageNumber) async {
    final bytes = await File(filePath).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final size = doc.pages[pageNumber - 1].size;
    doc.dispose();
    return size;
  }
}

class OptimizedPdfPreview extends StatefulWidget {
  final String filePath;
  final int pageNumber;
  final int rotation;

  const OptimizedPdfPreview({
    Key? key,
    required this.filePath,
    required this.pageNumber,
    required this.rotation,
  }) : super(key: key);

  @override
  State<OptimizedPdfPreview> createState() => _OptimizedPdfPreviewState();
}

class _OptimizedPdfPreviewState extends State<OptimizedPdfPreview> {
  PdfViewerController? _controller;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && _controller != null && mounted) {
        _controller!.jumpToPage(widget.pageNumber);
      }
    });
  }

  @override
  void didUpdateWidget(OptimizedPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.filePath != widget.filePath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && _controller != null && mounted) {
          _controller!.jumpToPage(widget.pageNumber);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRect(
      child: RotatedBox(
        quarterTurns: widget.rotation ~/ 90,
        child: SfPdfViewer.file(
          File(widget.filePath),
          controller: _controller!,
          key: ValueKey(
              'preview_${widget.filePath}_${widget.pageNumber}_${widget.rotation}'),
          enableDoubleTapZooming: false,
          enableTextSelection: false,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          pageLayoutMode: PdfPageLayoutMode.single,
          interactionMode: PdfInteractionMode.pan,
          scrollDirection: PdfScrollDirection.vertical,
          onPageChanged: (PdfPageChangedDetails details) {
            if (!_isDisposed &&
                details.newPageNumber != widget.pageNumber &&
                mounted) {
              Future.microtask(() {
                if (!_isDisposed && _controller != null && mounted) {
                  _controller!.jumpToPage(widget.pageNumber);
                }
              });
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}

class SignatureOverlay extends StatefulWidget {
  final SignatureInfo signature;
  final int rotation;
  final Function(SignatureInfo) onUpdate;
  final VoidCallback onDelete;

  const SignatureOverlay({
    Key? key,
    required this.signature,
    this.rotation = 0,
    required this.onUpdate,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<SignatureOverlay> createState() => _SignatureOverlayState();
}

class _SignatureOverlayState extends State<SignatureOverlay> {
  late double left, top, width, height;
  double? imageAspectRatio;

  @override
  void initState() {
    super.initState();
    left = widget.signature.left;
    top = widget.signature.top;
    width = widget.signature.width;
    height = widget.signature.height;
    _loadAspectRatio();
  }

  @override
  void didUpdateWidget(SignatureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature.left != widget.signature.left ||
        oldWidget.signature.top != widget.signature.top ||
        oldWidget.signature.width != widget.signature.width ||
        oldWidget.signature.height != widget.signature.height) {
      setState(() {
        left = widget.signature.left;
        top = widget.signature.top;
        width = widget.signature.width;
        height = widget.signature.height;
      });
      _loadAspectRatio();
    }
  }

  Future<void> _loadAspectRatio() async {
    final image = await decodeImageFromList(widget.signature.imageBytes);
    if (mounted) setState(() => imageAspectRatio = image.width / image.height);
    image.dispose();
  }

  void _push() => widget.onUpdate(SignatureInfo(
        imageBytes: widget.signature.imageBytes,
        left: left,
        top: top,
        width: width,
        height: height,
        pageIndex: widget.signature.pageIndex,
      ));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return Stack(
          children: [
            Positioned(
              left: left * constraints.maxWidth,
              top: top * constraints.maxHeight,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    left = (left + d.delta.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0 - width);
                    top = (top + d.delta.dy / constraints.maxHeight)
                        .clamp(0.0, 1.0 - height);
                  });
                  _push();
                },
                child: SizedBox(
                  width: width * constraints.maxWidth,
                  height: height * constraints.maxHeight,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.blue.shade500, width: 2.5),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withOpacity(0.15),
                                blurRadius: 8,
                                spreadRadius: 1),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.memory(
                            widget.signature.imageBytes,
                            fit: BoxFit.fill,
                            width: double.infinity,
                            height: double.infinity,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                      _corner(top: -1, left: -1),
                      _corner(top: -1, right: -1),
                      _corner(bottom: -1, left: -1),
                      Positioned(
                        bottom: -1,
                        right: -1,
                        child: GestureDetector(
                          onPanUpdate: (d) {
                            setState(() {
                              if (imageAspectRatio != null) {
                                final dh =
                                    d.delta.dy / constraints.maxHeight;
                                width = (width + dh * imageAspectRatio!)
                                    .clamp(0.03, 1.0 - left);
                                height = (height + dh)
                                    .clamp(0.03, 1.0 - top);
                              }
                            });
                            _push();
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.unfold_more,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -14,
                        right: -14,
                        child: GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.close_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _corner(
          {double? top, double? bottom, double? left, double? right}) =>
      Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                Border.all(color: Colors.blue.shade500, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Classes
// ─────────────────────────────────────────────────────────────────────────────
class PdfFileInfo {
  final String filePath;
  final String fileName;
  final int pageCount;
  PdfFileInfo(
      {required this.filePath,
      required this.fileName,
      required this.pageCount});
}

class PageInfo {
  final String filePath;
  final String fileName;
  final int pageNumber;
  final int totalPages;
  PageInfo(
      {required this.filePath,
      required this.fileName,
      required this.pageNumber,
      required this.totalPages});
}

class SignatureInfo {
  final Uint8List imageBytes;
  final double left, top, width, height;
  final int pageIndex;
  SignatureInfo(
      {required this.imageBytes,
      required this.left,
      required this.top,
      required this.width,
      required this.height,
      required this.pageIndex});
}