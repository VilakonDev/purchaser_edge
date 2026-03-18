import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/model/document_model.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/services/send_email_service.dart';
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
  String selectedDocumentCategory = 'ທັງຫມົດ';
  int selectedStatus = 0;

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  /// กรอง documents ตาม selectedStatus
  /// 0 = ທັງໝົດ, 1 = ລໍຖ້າ (PENDING + DM_APPROVED), 2 = ອະນຸມັດແລ້ວ (DIRECTOR_APPROVED)
  List<DocumentModel> _filterByStatus(List<DocumentModel> docs) {
    switch (selectedStatus) {
      case 1:
        return docs
            .where((d) => d.status == "PENDING" || d.status == "DM_APPROVED")
            .toList();
      case 2:
        return docs.where((d) => d.status == "DIRECTOR_APPROVED").toList();
      default:
        return docs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    final isPurchaser = currentUser.role == "PURCHASER";

    // ดึง docs ทั้งหมดก่อน แล้วค่อย filter status ทีหลัง
    final allDocs = isPurchaser
        ? context.watch<DocumentProvider>().showDocumentByOfficerCategory(
            currentUser.category,
          )
        : context.watch<DocumentProvider>().showAllDocuments(
            selectedDocumentCategory,
          );

    final documents = _filterByStatus(allDocs);

    final fileLauncher = context.read<FileProvider>();

    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(label: 'ເອກະສານທັງໝົດ', widget: Container()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (!isPurchaser) ...[
                    const SizedBox(height: 20),
                    _buildSearchBox(),
                  ],
                  const SizedBox(height: 20),

                  // Summary chips — 3 อัน
                  Row(
                    children: [
                      _summaryChip(
                        icon: UniconsLine.file_alt,
                        label: 'ທັງໝົດ',
                        count: allDocs.length,
                        color: ColorService().primaryColor,
                        index: 0,
                      ),
                      const SizedBox(width: 10),
                      _summaryChip(
                        icon: UniconsLine.clock,
                        label: 'ລໍຖ້າ',
                        count: allDocs
                            .where(
                              (d) =>
                                  d.status == "PENDING" ||
                                  d.status == "DM_APPROVED",
                            )
                            .length,
                        color: Colors.orange,
                        index: 1,
                      ),
                      const SizedBox(width: 10),
                      _summaryChip(
                        icon: UniconsLine.check_circle,
                        label: 'ອະນຸມັດແລ້ວ',
                        count: allDocs
                            .where((d) => d.status == "DIRECTOR_APPROVED")
                            .length,
                        color: ColorService().successColor,
                        index: 2,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  documents.isEmpty
                      ? _buildEmptyState()
                      : Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _verticalController,
                            itemCount: documents.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final doc = documents[index];
                              final isPending = doc.status == "PENDING";
                              final isDmApproved =
                                  doc.status == "DM_APPROVED" ||
                                  doc.status == "DIRECTOR_APPROVED";
                              final isDirectorApproved =
                                  doc.status == "DIRECTOR_APPROVED";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
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
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.08),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Icon box
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: ColorService().primaryColor
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          UniconsLine.file_alt,
                                          color: ColorService().primaryColor,
                                          size: 22,
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    doc.documentTitle,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    doc.documentNumber,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                _metaChip(
                                                  icon: UniconsLine.folder,
                                                  label: doc.documentCategory,
                                                ),
                                                _metaChip(
                                                  icon: UniconsLine.user,
                                                  label: doc.fullName,
                                                ),
                                                _metaChip(
                                                  icon:
                                                      UniconsLine.calendar_alt,
                                                  label: DateFormat('d MMM y')
                                                      .format(
                                                        DateTime.parse(
                                                          doc.createdAt,
                                                        ),
                                                      ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 10),

                                            Row(
                                              children: [
                                                _statusBadge(
                                                  label: 'ຜູ້ຈັດການ',
                                                  approved: isDmApproved,
                                                ),
                                                const SizedBox(width: 8),
                                                _statusBadge(
                                                  label: 'ຜູ້ບໍລິຫານ',
                                                  approved: isDirectorApproved,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // View button
                                      GestureDetector(
                                        onTap: () {
                                          if (isPending) {
                                            fileLauncher.openFile(
                                              doc.filePending,
                                            );
                                          } else if (doc.status ==
                                              "DM_APPROVED") {
                                            fileLauncher.openFile(doc.fileDm);
                                          } else {
                                            fileLauncher.openFile(
                                              doc.fileDirector,
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            UniconsLine.eye,
                                            color: Colors.blue,
                                            size: 18,
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required int index,
  }) {
    final isSelected = selectedStatus == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Text("$count",style: TextStyle(color: color),),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({required String label, required bool approved}) {
    final color = approved ? ColorService().successColor : Colors.orange;
    final statusText = approved ? 'ອະນຸມັດແລ້ວ' : 'ລໍຖ້າ';
    final statusIcon = approved ? UniconsLine.check_circle : UniconsLine.clock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $statusText',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(UniconsLine.file_slash, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'ບໍ່ມີເອກະສານ',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: DropDownWidget(
              label: 'ກຸ່ມສິນຄ້າ',
              items: ['ທັງຫມົດ', ...context.read<DocumentProvider>().category],
              onChanged: (value) {
                setState(() {
                  selectedDocumentCategory = value.toString();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
             SendEmailService().sendEmail('vilakonsili@gmail.com','TEST NOTIFICATION','New PO for pending approve');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: ColorService().primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(UniconsLine.search, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('ຄົ້ນຫາ', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
