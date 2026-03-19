import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    final role = currentUser.role;
    final docProvider = context.watch<DocumentProvider>();

    final documents = role == "DISTRICT_MANAGER"
        ? docProvider.pendingDocument
        : role == "DIRECTOR"
        ? docProvider.dmApprovedDocument
        : [];

    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(label: 'ອະນຸມັດເອກະສານ', widget: Container()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── List ───────────────────────────────────────────
                  Expanded(
                    child: documents.isEmpty
                        ? _buildEmptyState()
                        : Scrollbar(
                            controller: _verticalController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _verticalController,
                              itemCount: documents.length,
                              itemBuilder: (context, index) {
                                final doc = documents[index];
                                final isPending = doc.status == "PENDING";
                                final isDmApproved =
                                    doc.status == "DM_APPROVED";
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
                                              // Title + doc number
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
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      doc.documentNumber,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 8),

                                              // Meta chips
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
                                                    icon: UniconsLine
                                                        .calendar_alt,
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

                                              // Status badges
                                              Row(
                                                children: [
                                                  _statusBadge(
                                                    label: 'ຜູ້ຈັດການ',
                                                    approved: !isPending,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _statusBadge(
                                                    label: 'ຜູ້ບໍລິຫານ',
                                                    approved:
                                                        isDirectorApproved,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Action buttons
                                        Column(
                                          children: [
                                            // View button
                                            GestureDetector(
                                              onTap: () {
                                                final url = isPending
                                                    ? "http://localhost:5000/uploads/${doc.filePending}"
                                                    : isDmApproved
                                                    ? "http://localhost:5000/uploads/${doc.fileDm}"
                                                    : "http://localhost:5000/uploads/${doc.fileDirector}";
                                                context
                                                    .read<FileProvider>()
                                                    .openFile(url);
                                              },
                                              child: Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  UniconsLine.eye,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            // Approve button
                                            if (role == "DISTRICT_MANAGER" ||
                                                role == "DIRECTOR")
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ApproveScreen(
                                                        fileName:
                                                            role ==
                                                                "DISTRICT_MANAGER"
                                                            ? doc.filePending
                                                            : doc.fileDm,
                                                        documentId: doc.id
                                                            .toString(),
                                                        documentNumber:
                                                            doc.documentNumber,
                                                        documentTitle:
                                                            doc.documentTitle,
                                                        creatorEmail: doc.email,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: ColorService()
                                                        .successColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    UniconsLine.check_circle,
                                                    color: ColorService()
                                                        .successColor,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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
            'ບໍ່ມີເອກະສານລໍຖ້າອະນຸມັດ',
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
}
