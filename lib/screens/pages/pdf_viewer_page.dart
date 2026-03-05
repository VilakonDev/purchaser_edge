import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/services/color_service.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:unicons/unicons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cache กลางเก็บ thumbnail images เพื่อไม่ต้อง render ซ้ำ
// ────────────────────────────────────────────────────────��────────────────────
final Map<String, Uint8List> _thumbnailImageCache = {};

class PdfViewerPage extends StatefulWidget {
  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
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
    if (mounted) {
      _syncFromProvider();
    }
  }

  Future<void> _syncFromProvider() async {
    if (!mounted) return;

    final providerFiles = _fileProvider.files;
    final newPaths = providerFiles.map((f) => f.path).toList();
    if (_listEquals(newPaths, _loadedFilePaths)) return;
    _loadedFilePaths = List.from(newPaths);
    await _loadFilesFromProvider(providerFiles);
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
        loaded.add(
          PdfFileInfo(
            filePath: file.path,
            fileName: file.path.split('/').last,
            pageCount: doc.pages.count,
          ),
        );
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
    _thumbnailImageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ========== Header Bar ==========
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: ColorService().mainGredientColor,
            ),
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () {
                    Future.microtask(() {
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Icon(UniconsLine.arrow_left),
                        Text(
                          'ກັບຄືນ',
                          style: TextStyle(color: ColorService().mainTextColor),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action Buttons
                Row(
                  spacing: 10,
                  children: [
                    // Add Signature Button
                    if (selectedPageIndex != null)
                      GestureDetector(
                        onTap: () {
                          pickSignature();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            spacing: 10,
                            children: [
                              Text(
                                'ເພີ່ມລາຍເຊັນ',
                                style: TextStyle(color: Colors.white),
                              ),
                              Icon(Icons.edit_road, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    // Reload Documents Button
                    
                    // Merge Documents Button
                    GestureDetector(
                      onTap: pdfFiles.isEmpty ? null : mergeFilesWithUI,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        height: 40,
                        decoration: BoxDecoration(
                          color: pdfFiles.isEmpty
                              ? Colors.grey.shade300
                              : Colors.green.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          spacing: 10,
                          children: [
                            Text(
                              'ບິນທຶກເອກະສານ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Icon(Icons.save, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ========== Main Content ==========
          Expanded(
            child: Row(
              children: [
                // ========== Left Sidebar - Thumbnails ==========
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(12),
                        color: Colors.blue.shade50,
                        child: Row(
                          children: [
                            Icon(
                              Icons.view_module,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ເອກະສານທັງໝົດ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Thumbnails List
                      Expanded(
                        child: pdfFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'ຍັງບໍ່ມີເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ReorderableListView.builder(
                                scrollController: _thumbnailScrollController,
                                physics: ClampingScrollPhysics(),
                                padding: EdgeInsets.all(8),
                                itemCount: getAllPages().length,
                                onReorder: (oldIndex, newIndex) {
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
                                    Map<int, List<SignatureInfo>>
                                        newSignatures = {};
                                    pageSignatures.forEach((key, signatures) {
                                      int newKey = key;
                                      if (key == oldIndex) {
                                        newKey = newIndex;
                                      } else if (oldIndex < newIndex &&
                                          key > oldIndex &&
                                          key <= newIndex) {
                                        newKey = key - 1;
                                      } else if (oldIndex > newIndex &&
                                          key >= newIndex &&
                                          key < oldIndex) {
                                        newKey = key + 1;
                                      }
                                      newSignatures[newKey] = signatures
                                          .map(
                                            (sig) => SignatureInfo(
                                              imageBytes: sig.imageBytes,
                                              left: sig.left,
                                              top: sig.top,
                                              width: sig.width,
                                              height: sig.height,
                                              pageIndex: newKey,
                                            ),
                                          )
                                          .toList();
                                    });
                                    pageSignatures = newSignatures;
                                    Map<int, int> newRotations = {};
                                    pageRotations.forEach((key, rotation) {
                                      int newKey = key;
                                      if (key == oldIndex) {
                                        newKey = newIndex;
                                      } else if (oldIndex < newIndex &&
                                          key > oldIndex &&
                                          key <= newIndex) {
                                        newKey = key - 1;
                                      } else if (oldIndex > newIndex &&
                                          key >= newIndex &&
                                          key < oldIndex) {
                                        newKey = key + 1;
                                      }
                                      newRotations[newKey] = rotation;
                                    });
                                    pageRotations = newRotations;
                                    if (selectedPageIndex != null) {
                                      if (selectedPageIndex == oldIndex) {
                                        selectedPageIndex = newIndex;
                                      } else if (oldIndex < newIndex &&
                                          selectedPageIndex! > oldIndex &&
                                          selectedPageIndex! <= newIndex) {
                                        selectedPageIndex =
                                            selectedPageIndex! - 1;
                                      } else if (oldIndex > newIndex &&
                                          selectedPageIndex! >= newIndex &&
                                          selectedPageIndex! < oldIndex) {
                                        selectedPageIndex =
                                            selectedPageIndex! + 1;
                                      }
                                    }
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final pageInfo = getAllPages()[index];
                                  bool isSelected = selectedPageIndex == index;
                                  bool hasSignature =
                                      pageSignatures.containsKey(index) &&
                                      pageSignatures[index]!.isNotEmpty;

                                  return GestureDetector(
                                    key: ValueKey('page_$index'),
                                    onTap: () {
                                      setState(() {
                                        selectedPageIndex = index;
                                      });
                                    },
                                    child: Container(
                                      key: _thumbnailKeys[index],
                                      margin: EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Toolbar
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Icon(
                                                  Icons.drag_handle,
                                                  color: Colors.grey.shade400,
                                                  size: 20,
                                                ),
                                                Row(
                                                  children: [
                                                    // Signature Count Badge
                                                    if (hasSignature)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 4,
                                                            ),
                                                        child: Container(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .blue
                                                                .shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              10,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.edit,
                                                                color:
                                                                    Colors.blue,
                                                                size: 14,
                                                              ),
                                                              SizedBox(
                                                                width: 2,
                                                              ),
                                                              Text(
                                                                '${pageSignatures[index]!.length}',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .blue,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    // Rotate Button
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          int currentRotation =
                                                              pageRotations[index] ??
                                                              0;
                                                          pageRotations[index] =
                                                              (currentRotation +
                                                                  90) %
                                                              360;
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.all(
                                                          4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .blue
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Icon(
                                                          Icons.rotate_right,
                                                          color: Colors.blue,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    // Delete Button
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          if (selectedPageIndex ==
                                                              index) {
                                                            selectedPageIndex =
                                                                null;
                                                          } else if (selectedPageIndex !=
                                                                  null &&
                                                              selectedPageIndex! >
                                                                  index) {
                                                            selectedPageIndex =
                                                                selectedPageIndex! -
                                                                1;
                                                          }
                                                          allPages.removeAt(
                                                            index,
                                                          );
                                                          pageSignatures.remove(
                                                            index,
                                                          );
                                                          pageRotations.remove(
                                                            index,
                                                          );
                                                          Map<
                                                            int,
                                                            List<SignatureInfo>
                                                          >
                                                          updatedSignatures =
                                                              {};
                                                          pageSignatures
                                                              .forEach(
                                                            (key, value) {
                                                              updatedSignatures[key >
                                                                          index
                                                                      ? key - 1
                                                                      : key] =
                                                                  value;
                                                            },
                                                          );
                                                          pageSignatures =
                                                              updatedSignatures;
                                                          Map<int, int>
                                                              updatedRotations =
                                                              {};
                                                          pageRotations
                                                              .forEach(
                                                            (key, value) {
                                                              updatedRotations[key >
                                                                          index
                                                                      ? key - 1
                                                                      : key] =
                                                                  value;
                                                            },
                                                          );
                                                          pageRotations =
                                                              updatedRotations;
                                                          _pageKeys.remove(
                                                            index,
                                                          );
                                                          _thumbnailKeys.remove(
                                                            index,
                                                          );
                                                          String cacheKey =
                                                              '${pageInfo.filePath}_${pageInfo.pageNumber}';
                                                          _pageSizeCache.remove(
                                                            cacheKey,
                                                          );
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.all(
                                                          4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .red
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.red,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Thumbnail Image
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: OptimizedPdfThumbnail(
                                              filePath: pageInfo.filePath,
                                              pageNumber: pageInfo.pageNumber,
                                              rotation:
                                                  pageRotations[index] ?? 0,
                                            ),
                                          ),
                                          // Page Number
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue.shade50
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                bottom: Radius.circular(7),
                                              ),
                                            ),
                                            child: Text(
                                              'ຫນ້າ ${index + 1}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                // ========== Right Content - PDF Preview ==========
                Expanded(
                  child: Column(
                    children: [
                      // Main PDF Display Area
                      Expanded(
                        flex: 4,
                        child: pdfFiles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'ບໍ່ມີເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade200,
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
                                          onSignatureUpdate:
                                              (index, updatedSignature) {
                                            setState(() {
                                              pageSignatures[selectedPageIndex!]![
                                                  index] = updatedSignature;
                                            });
                                          },
                                          onSignatureDelete: (index) {
                                            setState(() {
                                              pageSignatures[selectedPageIndex!]!
                                                  .removeAt(index);
                                              if (pageSignatures[
                                                      selectedPageIndex!]!
                                                  .isEmpty) {
                                                pageSignatures.remove(
                                                  selectedPageIndex!,
                                                );
                                              }
                                            });
                                          },
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.touch_app,
                                              size: 80,
                                              color: Colors.grey.shade400,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'ກົດເລືອກຫນ້າຈາກດ້ານຊ້າຍ',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                      ),
                      // Status Footer
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: mergedFilePath != null
                            ? Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'ລວມເອກະສານສໍາເລັດ: $mergedFilePath',
                                        style: TextStyle(
                                          color: Colors.green.shade900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int getTotalPages() {
    return pdfFiles.fold(0, (sum, file) => sum + file.pageCount);
  }

  List<PageInfo> getAllPages() {
    return allPages;
  }

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
        allPages.add(
          PageInfo(
            filePath: file.filePath,
            fileName: file.fileName,
            pageNumber: i,
            totalPages: file.pageCount,
          ),
        );
        _pageKeys[index] = GlobalKey();
        _thumbnailKeys[index] = GlobalKey();
        index++;
      }
    }
  }

  Future<Size> getPageSizeCached(String filePath, int pageNumber) async {
    String cacheKey = '${filePath}_$pageNumber';
    if (_pageSizeCache.containsKey(cacheKey)) {
      return _pageSizeCache[cacheKey]!;
    }
    final bytes = await File(filePath).readAsBytes();
    PdfDocument doc = PdfDocument(inputBytes: bytes);
    Size size = doc.pages[pageNumber - 1].size;
    doc.dispose();
    _pageSizeCache[cacheKey] = size;
    return size;
  }

  Future<void> pickSignature() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      final bytes = await File(result.files.single.path!).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 800);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final compressedBytes = byteData!.buffer.asUint8List();
      double aspectRatio = image.width / image.height;

      if (selectedPageIndex != null && mounted) {
        final pageInfo = getAllPages()[selectedPageIndex!];
        final originalSize = await getPageSizeCached(
          pageInfo.filePath,
          pageInfo.pageNumber,
        );
        final rotation = pageRotations[selectedPageIndex!] ?? 0;

        Size rotatedSize = originalSize;
        if (rotation == 90 || rotation == 270) {
          rotatedSize = Size(originalSize.height, originalSize.width);
        }

        double signatureWidthRatio = 3.0 / 21.0;
        if (rotatedSize.width > rotatedSize.height) {
          signatureWidthRatio = 3.0 / 29.7;
        }
        double sigWidth = signatureWidthRatio;
        double sigHeight = sigWidth / aspectRatio;

        setState(() {
          if (!pageSignatures.containsKey(selectedPageIndex!)) {
            pageSignatures[selectedPageIndex!] = [];
          }
          pageSignatures[selectedPageIndex!]!.add(
            SignatureInfo(
              imageBytes: compressedBytes,
              left: 0.05,
              top: 0.85,
              width: sigWidth,
              height: sigHeight,
              pageIndex: selectedPageIndex!,
            ),
          );
        });
      }
      image.dispose();
    }
  }

  Future<void> mergeFilesWithUI() async {
    try {
      final mergedBytes = await mergeFromPages(allPages);
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'ບັນທຶກເອກະສານ',
        fileName: 'merged_document.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (outputPath != null) {
        if (!outputPath.toLowerCase().endsWith('.pdf')) {
          outputPath = '$outputPath.pdf';
        }
        await File(outputPath).writeAsBytes(mergedBytes);
        if (mounted) {
          setState(() {
            mergedFilePath = outputPath;
            pdfFiles.clear();
            allPages.clear();
            pageSignatures.clear();
            pageRotations.clear();
            selectedPageIndex = null;
            _pageKeys.clear();
            _thumbnailKeys.clear();
            _pageSizeCache.clear();
            _loadedFilePaths.clear();
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ບັນທຶກເອກະສານສໍາເລັດ!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ເປີດໃຫມ່',
              textColor: Colors.white,
              onPressed: () {
                if (mounted) {
                  setState(() => mergedFilePath = null);
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ຍົກເລີກການບັນທຶກ'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດ: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        for (final SignatureInfo sig in pageSignatures[i]!) {
          double sl, st, sw, sh;
          final bool wasFlipped = (a.width - rW).abs() > 1.0;
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
          final PdfBitmap bmp = PdfBitmap(sig.imageBytes);
          newPage.graphics.drawImage(bmp, Rect.fromLTWH(sl, st, sw, sh));
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

    for (int i = 0; i < pageBytesList.length; i++) {
      final PdfDocument srcDoc = PdfDocument(inputBytes: pageBytesList[i]);
      final PdfPage srcPage = srcDoc.pages[0];
      final Size srcSize = srcPage.size;

      mergedDoc.pageSettings.margins.all = 0;
      mergedDoc.pageSettings.size = srcSize;
      mergedDoc.pageSettings.orientation = srcSize.width > srcSize.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final PdfPage destPage = mergedDoc.pages.add();
      final Size da = destPage.size;
      final PdfTemplate srcTmpl = srcPage.createTemplate();

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

    final List<int> mergedBytes = await mergedDoc.save();
    mergedDoc.dispose();
    return Uint8List.fromList(mergedBytes);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OptimizedPdfThumbnail Widget
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
  State<OptimizedPdfThumbnail> createState() => _OptimizedPdfThumbnailState();
}

class _OptimizedPdfThumbnailState extends State<OptimizedPdfThumbnail> {
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(OptimizedPdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.rotation != widget.rotation) {
      final oldKey =
          '${oldWidget.filePath}_${oldWidget.pageNumber}_${oldWidget.rotation}';
      _thumbnailImageCache.remove(oldKey);
      _loadThumbnail();
    }
  }

  String get _cacheKey =>
      '${widget.filePath}_${widget.pageNumber}_${widget.rotation}';

  Future<void> _loadThumbnail() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_thumbnailImageCache.containsKey(_cacheKey)) {
      if (mounted) {
        setState(() {
          _imageBytes = _thumbnailImageCache[_cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final document = await pdfrx.PdfDocument.openFile(widget.filePath);
      final page = document.pages[widget.pageNumber - 1];

      const double dpi = 96.0;
      final double scale = dpi / 72.0;
      final int imgW = (page.width * scale).round();
      final int imgH = (page.height * scale).round();

      final pdfrx.PdfImage? pageImage = await page.render(
        fullWidth: imgW.toDouble(),
        fullHeight: imgH.toDouble(),
      );

      document.dispose();

      if (pageImage == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        pageImage.pixels,
      );
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.raw(
        buffer,
        width: pageImage.width,
        height: pageImage.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frameInfo.image.dispose();

      if (byteData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      Uint8List finalBytes = await _rotateImage(pngBytes, widget.rotation);

      _thumbnailImageCache[_cacheKey] = finalBytes;

      if (mounted) {
        setState(() {
          _imageBytes = finalBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Thumbnail error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _rotateImage(Uint8List src, int rotation) async {
    if (rotation == 0) return src;

    final ui.Codec codec = await ui.instantiateImageCodec(src);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image img = frame.image;

    final int w = img.width;
    final int h = img.height;

    late int canvasW;
    late int canvasH;

    if (rotation == 90 || rotation == 270) {
      canvasW = h;
      canvasH = w;
    } else {
      canvasW = w;
      canvasH = h;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.translate(canvasW / 2, canvasH / 2);
    canvas.rotate(rotation * 3.141592653589793 / 180.0);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawImage(img, Offset.zero, Paint());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image rotated = await picture.toImage(canvasW, canvasH);
    final ByteData? byteData = await rotated.toByteData(
      format: ui.ImageByteFormat.png,
    );

    img.dispose();
    rotated.dispose();

    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 160,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_imageBytes == null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey,
            size: 32,
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

  @override
  void dispose() {
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SinglePagePreview Widget
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
          return Center(child: CircularProgressIndicator());
        }
        Size pageSize = snapshot.data!;

        double finalWidth = pageSize.width;
        double finalHeight = pageSize.height;
        if (rotation == 90 || rotation == 270) {
          finalWidth = pageSize.height;
          finalHeight = pageSize.width;
        }

        double aspectRatio = finalWidth / finalHeight;
        return Padding(
          padding: EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
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
                            width: finalWidth,
                            height: finalHeight,
                            child: OptimizedPdfPreview(
                              filePath: pageInfo.filePath,
                              pageNumber: pageInfo.pageNumber,
                              rotation: rotation,
                            ),
                          ),
                        ),
                      ),
                      ...signatures.asMap().entries.map((entry) {
                        int sigIndex = entry.key;
                        SignatureInfo sig = entry.value;
                        return SignatureOverlay(
                          signature: sig,
                          rotation: rotation,
                          onUpdate: (updatedSignature) {
                            onSignatureUpdate(sigIndex, updatedSignature);
                          },
                          onDelete: () {
                            onSignatureDelete(sigIndex);
                          },
                        );
                      }).toList(),
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
    PdfDocument doc = PdfDocument(inputBytes: bytes);
    Size size = doc.pages[pageNumber - 1].size;
    doc.dispose();
    return size;
  }
}

// ────────────────────────────────────────────────────────────────��────────────
// OptimizedPdfPreview Widget
// ─────────────────────────────────────────────────────────────────────────────

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
    if (_controller == null) return Center(child: CircularProgressIndicator());

    Widget pdfViewer = SfPdfViewer.file(
      File(widget.filePath),
      controller: _controller!,
      key: ValueKey(
        'preview_${widget.filePath}_${widget.pageNumber}_${widget.rotation}',
      ),
      enableDoubleTapZooming: false,
      enableTextSelection: false,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      pageLayoutMode: PdfPageLayoutMode.single,
      interactionMode: PdfInteractionMode.pan,
      scrollDirection: PdfScrollDirection.vertical,
      onPageChanged: (PdfPageChangedDetails details) {
        if (!_isDisposed && details.newPageNumber != widget.pageNumber && mounted) {
          Future.microtask(() {
            if (!_isDisposed && _controller != null && mounted) {
              _controller!.jumpToPage(widget.pageNumber);
            }
          });
        }
      },
    );

    return ClipRect(
      child: RotatedBox(quarterTurns: widget.rotation ~/ 90, child: pdfViewer),
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

// ─────────────────────────────────────────────────────────────────────────────
// SignatureOverlay Widget
// ─────────────────────────────────────────────────────────────────────────────

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
  late double left;
  late double top;
  late double width;
  late double height;
  double? imageAspectRatio;

  @override
  void initState() {
    super.initState();
    left = widget.signature.left;
    top = widget.signature.top;
    width = widget.signature.width;
    height = widget.signature.height;
    _loadImageAspectRatio();
  }

  Future<void> _loadImageAspectRatio() async {
    final image = await decodeImageFromList(widget.signature.imageBytes);
    if (mounted) {
      setState(() {
        imageAspectRatio = image.width / image.height;
      });
    }
    image.dispose();
  }

  void _updateSignature() {
    widget.onUpdate(
      SignatureInfo(
        imageBytes: widget.signature.imageBytes,
        left: left,
        top: top,
        width: width,
        height: height,
        pageIndex: widget.signature.pageIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              left: left * constraints.maxWidth,
              top: top * constraints.maxHeight,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    left += details.delta.dx / constraints.maxWidth;
                    top += details.delta.dy / constraints.maxHeight;
                    left = left.clamp(0.0, 1.0 - width);
                    top = top.clamp(0.0, 1.0 - height);
                  });
                  _updateSignature();
                },
                child: Container(
                  width: width * constraints.maxWidth,
                  height: height * constraints.maxHeight,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.shade500,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
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
                          onPanUpdate: (details) {
                            setState(() {
                              double deltaHeight =
                                  details.delta.dy / constraints.maxHeight;
                              if (imageAspectRatio != null) {
                                double deltaWidth =
                                    deltaHeight * imageAspectRatio!;
                                width += deltaWidth;
                                height += deltaHeight;
                                width = width.clamp(0.03, 1.0 - left);
                                height = height.clamp(0.03, 1.0 - top);
                              }
                            });
                            _updateSignature();
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: Icon(
                              Icons.unfold_more,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -14,
                        right: -14,
                        child: GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
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

  Widget _corner({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue.shade500, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Classes
// ─────────────────────────────────────────────────────────────────────────────

class PdfFileInfo {
  final String filePath;
  final String fileName;
  final int pageCount;

  PdfFileInfo({
    required this.filePath,
    required this.fileName,
    required this.pageCount,
  });
}

class PageInfo {
  final String filePath;
  final String fileName;
  final int pageNumber;
  final int totalPages;

  PageInfo({
    required this.filePath,
    required this.fileName,
    required this.pageNumber,
    required this.totalPages,
  });
}

class SignatureInfo {
  final Uint8List imageBytes;
  final double left;
  final double top;
  final double width;
  final double height;
  final int pageIndex;

  SignatureInfo({
    required this.imageBytes,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.pageIndex,
  });
}