import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/screens/pages/pdf_viewer_page.dart';
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
    // ✅ watch ที่เดียว ครอบทุกอย่าง
    final files = context.watch<FileProvider>().files;

    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(label: 'ສ້າງເອກະສານສັ່ງຊື້', widget: Container()),
          Expanded(
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: Column(
                spacing: 20,
                children: [
                  _buildDocumentInfo(),

                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  pickFiles();
                                },
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: ColorService().mainGredientColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    spacing: 10,
                                    children: [
                                      Text(
                                        'ເພີ່ມເອກະສານ',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      Icon(
                                        UniconsLine.paperclip,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          files.isEmpty
                              ? Column(
                                  spacing: 10,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      UniconsLine.file,
                                      size: 100,
                                      color: Colors.grey.shade300,
                                    ),
                                    Text(
                                      'ຍັງບໍ່ມີຟາຍ',
                                      style: TextStyle(
                                        fontSize: 18,

                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                )
                              : Expanded(
                                  child: ListView.builder(
                                    itemCount: files.length,
                                    itemBuilder: (context, index) {
                                      final file = files[index];
                                      return Container(
                                        width: double.infinity,
                                        height: 40,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(p.basename(file.path)),
                                            GestureDetector(
                                              onTap: () => context
                                                  .read<FileProvider>()
                                                  .deleteFile(index),
                                              child: Icon(
                                                UniconsLine.trash,
                                                color: Colors.red.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          Container(height: 50),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomButton(files),
                  Container(),
                ],
              ),
            ),
          ),
          Container(),
        ],
      ),
    );
  }

  Widget _buildDocumentInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ລາຍລະອຽດເອກະສານ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: ColorService().mainTextColor,
            ),
          ),
          TextFiledWidget(
            label: 'ຊື່ເອກະສານ',
            controller: TextEditingController(),
          ),
          Row(
            spacing: 20,
            children: [
              Expanded(
                child: DropDownWidget(
                  label: 'ກຸ່ມເອກະສານ',
                  items: ['HT.PT.HO', 'PA.HW.DW.DM'],
                ),
              ),
              Expanded(
                child: DropDownWidget(
                  label: 'ກຸ່ມເອກະສານ',
                  items: ['HT.PT.HO', 'PA.HW.DW.DM'],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentGeometry.centerEnd,
                  child: Text(
                    DateFormat('EEE, M/d/y').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 16,
                      color: ColorService().mainTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(List<File> files) {
    return Container(
      width: double.infinity,
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (files.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PDFViewerHome()),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 2,
                  color: ColorService().mainTextFiledColor,
                ),
                color: files.isEmpty
                    ? Colors.transparent
                    : ColorService().primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                spacing: 10,
                children: [
                  Icon(
                    files.isEmpty ? UniconsLine.eye_slash : UniconsLine.eye,
                    color: files.isEmpty
                        ? ColorService().mainTextColor
                        : Colors.white,
                  ),
                  Text(
                    'ເປີດເອກະສານ',
                    style: TextStyle(
                      color: files.isEmpty
                          ? ColorService().mainTextColor
                          : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            spacing: 20,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: ColorService().mainTextFiledColor,
                  ),
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Icon(
                      UniconsLine.times,
                      color: ColorService().mainTextColor,
                    ),
                    Text(
                      'ຍົກເລີກ',
                      style: TextStyle(
                        color: ColorService().mainTextColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  height: 50,
                  decoration: BoxDecoration(
                    color: ColorService().primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    spacing: 10,
                    children: [
                      Text(
                        'ບັນທຶກເອກະສານ',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Icon(UniconsLine.save, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
