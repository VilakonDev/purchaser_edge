import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/user_provider.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/app_bar_widget.dart';
import 'package:purchaser_edge/widgets/drop_down_widget.dart';
import 'package:purchaser_edge/widgets/text_filed_widget.dart';
import 'package:unicons/unicons.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _verticalController = ScrollController();

  String? roleSelected;
  String? branchSelected;
  String? categorySelected;

  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordControlelr = TextEditingController();

  void pickSignatureFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpeg', 'png', 'jpg'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      context.read<UserProvider>().setSignature(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(
            label: 'ຈັດການສິດຜູ້ໃຊ້',
            widget: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => _buildCreateUser(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: ColorService().mainGredientColor,
                ),
                child: Row(
                  children: const [
                    Text('ເພີ່ມຜູ້ໃຊ້', style: TextStyle(color: Colors.white)),
                    SizedBox(width: 10),
                    Icon(UniconsLine.plus, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              trackVisibility: true,
              child: ListView.builder(
                controller: _verticalController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: context.watch<UserProvider>().users.length,
                itemBuilder: (context, index) {
                  final userData = context.read<UserProvider>().users[index];
                  final isOnline = userData.status == "online";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: ColorService().primaryColor
                                    .withOpacity(0.15),
                                child: Text(
                                  userData.fullName.isNotEmpty
                                      ? userData.fullName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: ColorService().primaryColor,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? Colors.green
                                        : ColorService().errorColor,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        userData.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorService().primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        userData.role,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: ColorService().primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  '@${userData.username}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Row(
                                  children: [
                                    _infoChip(
                                      UniconsLine.building,
                                      userData.branch,
                                    ),
                                    const SizedBox(width: 6),
                                    _infoChip(
                                      UniconsLine.users_alt,
                                      userData.category,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {},
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: ColorService().primaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    UniconsLine.info_circle,
                                    size: 18,
                                    color: ColorService().primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) =>
                                        _buildDeleteUser(userData.id),
                                  );
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: ColorService().errorColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    UniconsLine.times_circle,
                                    size: 18,
                                    color: ColorService().errorColor,
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
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateUser() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final isManagerOrAbove =
            roleSelected == "DISTRICT_MANAGER" ||
            roleSelected == "DIRECTOR" ||
            roleSelected == "PURCHASER_MANAGER";

        // ✅ watch signature จาก provider
        final signature = context.watch<UserProvider>().signature;
        final hasSignature = signature != null;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: 680,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: ColorService().mainGredientColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          UniconsLine.user_plus,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'ເພີ່ມ / ແກ້ໄຂຜູ້ໃຊ້',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('ຂໍ້ມູນທົ່ວໄປ'),
                      const SizedBox(height: 12),

                      // Full name + signature picker
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ຊື່ ແລະ ນາມສະກຸນ',
                              isHidden: false,
                              controller: fullNameController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              pickSignatureFile();
                              // ✅ บังคับ rebuild dialog หลัง pick
                              setDialogState(() {});
                            },
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: hasSignature
                                    ? ColorService().successColor.withOpacity(
                                        0.1,
                                      )
                                    : ColorService().primaryColor.withOpacity(
                                        0.08,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: hasSignature
                                      ? ColorService().successColor.withOpacity(
                                          0.3,
                                        )
                                      : ColorService().primaryColor.withOpacity(
                                          0.2,
                                        ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasSignature
                                        ? UniconsLine.check_circle
                                        : UniconsLine.paperclip,
                                    size: 16,
                                    color: hasSignature
                                        ? ColorService().successColor
                                        : ColorService().primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hasSignature
                                        ? 'ມີລາຍເຊັນແລ້ວ'
                                        : 'ເພີ່ມລາຍເຊັນ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: hasSignature
                                          ? ColorService().successColor
                                          : ColorService().primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Username + Password
                      Row(
                        children: [
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ຊື່ຜູ້ໃຊ້',
                              isHidden: false,
                              controller: usernameController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ລະຫັດຜ່ານ',
                              isHidden: false,
                              controller: passwordControlelr,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ອີເມວ ',
                              isHidden: false,
                              controller: emailController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.grey.shade100, height: 1),
                      const SizedBox(height: 20),

                      _sectionLabel('ສິດ ແລະ ໂຄງສ້າງ'),
                      const SizedBox(height: 12),

                      // Branch + Role
                      Row(
                        children: [
                          Expanded(
                            child: DropDownWidget(
                              label: 'ສາຂາ',
                              items: const [
                                'TCR_VTE',
                                'TCR_PAKSE01',
                                'TCR_PAKSE02',
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => branchSelected = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropDownWidget(
                              label: 'ສິດໃຊ້ງານ',
                              items: const [
                                'IT',
                                'PURCHASER',
                                'PURCHASER_MANAGER',
                                'DISTRICT_MANAGER',
                                'DIRECTOR',
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => roleSelected = value),
                            ),
                          ),
                        ],
                      ),

                      if (!isManagerOrAbove) ...[
                        const SizedBox(height: 12),
                        DropDownWidget(
                          label: 'ຮັບຜິດຊອບກຸ່ມ',
                          items: context.read<DocumentProvider>().category,
                          onChanged: (value) =>
                              setDialogState(() => categorySelected = value),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Signature warning
                      if (!hasSignature)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                UniconsLine.exclamation_triangle,
                                size: 16,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ກະລຸນາເພີ່ມລາຍເຊັນກ່ອນບັນທຶກ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Cancel
                          GestureDetector(
                            onTap: () {
                              context.read<UserProvider>().setSignature(null);
                              Future.microtask(
                                () => mounted ? Navigator.pop(context) : null,
                              );
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    UniconsLine.times,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ຍົກເລີກ',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // ✅ Save — disable ถ้าไม่มี signature
                          GestureDetector(
                            onTap: hasSignature
                                ? () async {
                                    await context.read<UserProvider>().addUser(
                                      fullNameController.text.trim(),
                                      usernameController.text.trim(),
                                      passwordControlelr.text.trim(),
                                      emailController.text.trim(),
                                      branchSelected.toString(),
                                      categorySelected.toString(),
                                      roleSelected.toString(),
                                    );

                                    fullNameController.text = "";
                                    usernameController.text = "";
                                    passwordControlelr.text = "";
                                    emailController.text = "";

                                    context.read<UserProvider>().setSignature(null);

                                    if (mounted) Navigator.pop(context);
                                  }
                                : null, // ✅ null = กดไม่ได้
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                gradient: hasSignature
                                    ? ColorService().mainGredientColor
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade300,
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: hasSignature
                                    ? [
                                        BoxShadow(
                                          color: ColorService().primaryColor
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    UniconsLine.save,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'ບັນທຶກ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeleteUser(int userId) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: 550,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  spacing: 20,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 50),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://cdn3d.iconscout.com/3d/premium/thumb/error-3d-icon-png-download-12692245.png',
                          ),
                        ),
                      ),
                    ),

                    Text(
                      "ຕ້ອງການລົບຜູ້ໃຊ້ ອີ່ຫລີຕິ່!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: double.infinity,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  spacing: 10,
                                  children: [
                                    Icon(UniconsLine.times),
                                    Text('ຍົກເລີກ'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                context.read<UserProvider>().deleteUser(userId);

                                Navigator.pop(context);
                              },
                              child: Container(
                                width: double.infinity,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: ColorService().errorColor,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.red.shade400,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  spacing: 10,
                                  children: [
                                    Icon(
                                      UniconsLine.trash,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      'ຢືນຢັນ',
                                      style: TextStyle(color: Colors.white),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: ColorService().primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
