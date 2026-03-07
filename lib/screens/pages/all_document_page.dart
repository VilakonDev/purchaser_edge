import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/app_bar_widget.dart';
import 'package:purchaser_edge/widgets/drop_down_widget.dart';
import 'package:unicons/unicons.dart';

class AllDocumentPage extends StatefulWidget {
  const AllDocumentPage({super.key});

  @override
  State<AllDocumentPage> createState() => _AllDocumentPageState();
}

class _AllDocumentPageState extends State<AllDocumentPage> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(label: 'ເອກະສານທັງໝົດ', widget: Container()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBox(),
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        notificationPredicate: (notif) =>
                            notif.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.of(context).size.width - 40,
                              ),
                              child: DataTable(
                                columnSpacing: 24,
                                headingRowColor: MaterialStatePropertyAll(
                                  Colors.blue.shade300,
                                ),
                                dataRowColor: const MaterialStatePropertyAll(
                                  Colors.white,
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'ເລກທີ່ເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ຊື່ເລື່ອງ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ກຸ່ມເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ຜູ້ສົ່ງເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ວັນທີສົ່ງເອກະສານ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ຜູ້ຈັດການເຂດ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ຜູ້ບໍລິຫານ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ຈັດການ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: List.generate(
                                  context
                                      .watch<DocumentProvider>()
                                      .documents
                                      .length,
                                  (index) {
                                    final cellData = context
                                        .watch<DocumentProvider>()
                                        .documents[index];

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(cellData.documentNumber)),
                                        DataCell(Text(cellData.documentTitle)),
                                        DataCell(
                                          Text(cellData.documentCategory),
                                        ),
                                        DataCell(Text(cellData.createdBy)),
                                        DataCell(Text(cellData.createdAt)),
                                        DataCell(
                                          cellData.status == "PENDING"
                                              ? Text('...........')
                                              : Container(
                                                  width: 120,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: ColorService()
                                                        .successColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'ອະນຸມັດແລ້ວ',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        DataCell(
                                          cellData.status == "PENDING"
                                              ? Text('...........')
                                              : Container(
                                                  width: 120,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: ColorService()
                                                        .successColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'ອະນຸມັດແລ້ວ',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        DataCell(
                                          Row(
                                            spacing: 10,
                                            children: [
                                              _buildActionButton(
                                                icon: UniconsLine.eye,
                                                color: Colors.blue,
                                                onPressed: () {
                                                  context
                                                      .read<FileProvider>()
                                                      .openFile(
                                                        "http://192.168.1.221:5000/uploads/${cellData.filePending}",
                                                      );
                                                },
                                              ),

                                              _buildActionButton(
                                                icon: UniconsLine.check,
                                                color: ColorService().successColor,
                                              ),
                                              _buildActionButton(
                                                icon: UniconsLine.backpack,
                                                color: Colors.red,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 10,
        children: [
         
          Expanded(
            child: DropDownWidget(
              label: 'ກຸ່ມສິນຄ້າ',
              items: context.read<DocumentProvider>().category,
            ),
          ),
          Expanded(
            child: DropDownWidget(
              label: 'ສະຖານະ',
              items: ['ອະນຸມັດແລ້ວ', 'ລໍຖ້າອະນຸມັດ', 'ເອກະສານຕີກັບ'],
            ),
          ),
          Container(width: 300, height: 40),
          Column(
            children: [
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                height: 40,
                decoration: BoxDecoration(
                  color: ColorService().primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Text('ຄົ້ນຫາ', style: TextStyle(color: Colors.white)),
                    Icon(UniconsLine.search, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
