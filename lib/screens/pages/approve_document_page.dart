import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/screens/approve_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/app_bar_widget.dart';

import 'package:unicons/unicons.dart';

class ApproveDocumentPage extends StatefulWidget {
  const ApproveDocumentPage({super.key});

  @override
  State<ApproveDocumentPage> createState() => _ApproveDocumentPageState();
}

class _ApproveDocumentPageState extends State<ApproveDocumentPage> {
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
          AppBarWidget(label: 'ອະນຸມັດເອກະສານ', widget: Container()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                              .read<AuthProvider>()
                                              .currentUser!
                                              .role ==
                                          "DISTRICT_MANAGER"
                                      ? context
                                            .watch<DocumentProvider>()
                                            .pendingDocument
                                            .length
                                      : context
                                                .read<AuthProvider>()
                                                .currentUser!
                                                .role ==
                                            "DIRECTOR"
                                      ? context
                                            .watch<DocumentProvider>()
                                            .dmApprovedDocument
                                            .length
                                      : 0,
                                  (index) {
                                    final cellData =
                                        context
                                                .read<AuthProvider>()
                                                .currentUser!
                                                .role ==
                                            "DISTRICT_MANAGER"
                                        ? context
                                              .watch<DocumentProvider>()
                                              .pendingDocument[index]
                                        : context
                                                  .read<AuthProvider>()
                                                  .currentUser!
                                                  .role ==
                                              "DIRECTOR"
                                        ? context
                                              .watch<DocumentProvider>()
                                              .dmApprovedDocument[index]
                                        : context
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
                                              : cellData.status ==
                                                    "DIRECTOR_APPROVED"
                                              ? Container(
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
                                                )
                                              : Container(),
                                        ),
                                        DataCell(
                                          Row(
                                            spacing: 10,
                                            children: [
                                              _buildActionButton(
                                                icon: UniconsLine.eye,
                                                color: Colors.blue,
                                                onPressed: () {
                                                  cellData.status == "PENDING"
                                                      ? context
                                                            .read<
                                                              FileProvider
                                                            >()
                                                            .openFile(
                                                              "http://localhost:5000/uploads/${cellData.filePending}",
                                                            )
                                                      : cellData.status ==
                                                            "DM_APPROVED"
                                                      ? context
                                                            .read<
                                                              FileProvider
                                                            >()
                                                            .openFile(
                                                              "http://localhost:5000/uploads/${cellData.fileDm}",
                                                            )
                                                      : context
                                                            .read<
                                                              FileProvider
                                                            >()
                                                            .openFile(
                                                              "http://localhost:5000/uploads/${cellData.fileDirector}",
                                                            );
                                                },
                                              ),

                                              context
                                                          .read<AuthProvider>()
                                                          .currentUser
                                                          ?.role ==
                                                      "DISTRICT_MANAGER"
                                                  ? _buildActionButton(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => ApproveScreen(
                                                              fileName: cellData
                                                                  .filePending,
                                                              documentId: cellData
                                                                  .id
                                                                  .toString(),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      icon: UniconsLine.check,
                                                      color: ColorService()
                                                          .successColor,
                                                    )
                                                  : context
                                                            .read<
                                                              AuthProvider
                                                            >()
                                                            .currentUser!
                                                            .role ==
                                                        "DIRECTOR"
                                                  ? _buildActionButton(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                ApproveScreen(
                                                                  fileName:
                                                                      cellData
                                                                          .fileDm,
                                                                  documentId:
                                                                      cellData
                                                                          .id
                                                                          .toString(),
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                      icon: UniconsLine.check,
                                                      color: ColorService()
                                                          .successColor,
                                                    )
                                                  : Container(),
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
}
