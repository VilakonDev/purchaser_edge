import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/screens/pdf_viewer_screen.dart';
import 'package:purchaser_edge/widgets/alert_dialog_widget.dart';
import 'package:purchaser_edge/widgets/text_filed_widget.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/app_bar_widget.dart';
import 'package:purchaser_edge/widgets/drop_down_widget.dart';
import 'package:unicons/unicons.dart';
import 'package:path/path.dart' as p;

class CreatePurchaseOrderPage extends StatefulWidget {
  const CreatePurchaseOrderPage({super.key});

  @override
  State<CreatePurchaseOrderPage> createState() =>
      _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  final documentNumberController = TextEditingController();
  final documentTitleController = TextEditingController();
  String? documentCategory;

  void pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      List<File> files = result.paths.map((path) => File(path!)).toList();
      context.read<FileProvider>().addFile(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FileProvider>().files;
    final currentUser = context.read<AuthProvider>().currentUser!;
    final isPurchaser = currentUser.role == "PURCHASER";

    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(label: 'ສ້າງເອກະສານສັ່ງຊື້', widget: Container()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Document info card ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // ✅ สำคัญมาก
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: ColorService()
                                        .primaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    UniconsLine.file_edit_alt,
                                    size: 18,
                                    color: ColorService().primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'ລາຍລະອຽດເອກະສານ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: ColorService().mainTextColor,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ColorService()
                                    .primaryColor
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    UniconsLine.calendar_alt,
                                    size: 13,
                                    color: ColorService().primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('EEE, d MMM y')
                                        .format(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: ColorService().primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // PO number + title
                        Row(
                          children: [
                            SizedBox(
                              width: 180,
                              child: TextFiledWidget(
                                label: 'ໝາຍເລກ PO',
                                isHidden: false,
                                controller: documentNumberController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFiledWidget(
                                label: 'ຊື່ເລື່ອງ',
                                isHidden: false,
                                controller: documentTitleController,
                              ),
                            ),
                          ],
                        ),

                        // Category (admin only)
                        if (!isPurchaser) ...[
                          const SizedBox(height: 16),
                          DropDownWidget(
                            label: 'ກຸ່ມເອກະສານ',
                            items: context.read<DocumentProvider>().category,
                            onChanged: (value) {
                              setState(() => documentCategory = value);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── File list card ───────────────────────────────────
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Top bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      UniconsLine.paperclip,
                                      size: 18,
                                      color: Colors.orange.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ໄຟລ໌ເອກະສານ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: ColorService().mainTextColor,
                                    ),
                                  ),
                                  if (files.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorService()
                                            .primaryColor
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${files.length}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: ColorService().primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              GestureDetector(
                                onTap: pickFiles,
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient:
                                        ColorService().mainGredientColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(UniconsLine.plus_circle,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'ເພີ່ມໄຟລ໌',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // File list or empty state
                          Expanded(
                            child: files.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            UniconsLine.file_upload_alt,
                                            size: 36,
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'ຍັງບໍ່ມີໄຟລ໌',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ກົດ "ເພີ່ມໄຟລ໌" ເພື່ອອັບໂຫລດ PDF',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: files.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                    itemBuilder: (context, index) {
                                      final file = files[index];
                                      final fileName =
                                          p.basename(file.file.path);

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                UniconsLine.file_alt,
                                                size: 16,
                                                color: Colors.red.shade400,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fileName,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: ColorService()
                                                          .mainTextColor,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'PDF Document',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors
                                                          .grey.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => context
                                                  .read<FileProvider>()
                                                  .deleteFile(index),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                ),
                                                child: Icon(
                                                  UniconsLine.trash_alt,
                                                  size: 15,
                                                  color: Colors.red.shade400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Bottom buttons ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Cancel
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 48,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(UniconsLine.times,
                                    color: Colors.grey.shade500, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ຍົກເລີກ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Proceed
                        GestureDetector(
                          onTap: () {
                            final documentNumber =
                                documentNumberController.text.trim();
                            final documentTitle =
                                documentTitleController.text.trim();
                            final category = isPurchaser
                                ? currentUser.category
                                : documentCategory.toString();

                            if (documentNumber.isEmpty ||
                                documentTitle.isEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialogWidget(
                                  type: 'error',
                                  textContent: 'ກະລຸນາໃສ່ຂໍ້ມູນໃຫ້ຄົບຖ້ວນ',
                                ),
                              );
                            } else {
                              context
                                  .read<DocumentProvider>()
                                  .setDocumentInfo(
                                    documentNumber,
                                    documentTitle,
                                    category,
                                    currentUser.branch,
                                    currentUser.id.toString(),
                                  );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PdfViewerScreen()),
                              );
                            }
                          },
                          child: Container(
                            height: 48,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              gradient: files.isEmpty
                                  ? LinearGradient(colors: [
                                      Colors.grey.shade300,
                                      Colors.grey.shade300,
                                    ])
                                  : ColorService().mainGredientColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: files.isEmpty
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: ColorService()
                                            .primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: const [
                                Text(
                                  'ດຳເນີນການຕໍ່',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(UniconsLine.arrow_right,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
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