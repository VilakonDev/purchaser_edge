import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final _horizontalController = ScrollController();
  final _vericalController = ScrollController();

  String? roleSelected;
  String? branchSelected;

  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordControlelr = TextEditingController();

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
                showDialog(context: context, builder: (_) => _buildCreteUser());
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: ColorService().mainGredientColor,
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Text('ເພີ່ມຜູ້ໃຊ້', style: TextStyle(color: Colors.white)),
                    Icon(UniconsLine.plus, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      notificationPredicate: (notif) =>
                          notif.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        controller: _vericalController,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalController,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width - 40,
                            ),
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                ColorService().primaryColor,
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'ຊື່ ແລະ ນາມສະກຸນ',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ຊື່ຜູ້ໃຊ້',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ສິດຜູ້ໃຊ້',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ສາຂາ',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ສະຖານະ',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ຈັດການ',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],

                              rows: List.generate(
                                context.watch<UserProvider>().users.length,
                                (index) {
                                  final userData = context
                                      .read<UserProvider>()
                                      .users[index];

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(userData.fullName)),
                                      DataCell(Text(userData.username)),
                                      DataCell(Text(userData.role)),
                                      DataCell(Text(userData.branch)),
                                      DataCell(
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: userData.status == "online"
                                                ? Colors.green
                                                : ColorService().errorColor,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          spacing: 5,
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    ColorService().errorColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  UniconsLine.times_circle,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    ColorService().primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  UniconsLine.info_circle,
                                                  color: Colors.white,
                                                ),
                                              ),
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
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCreteUser() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 700,

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: ColorService().mainGredientColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'ເພີ່ມຜູ້ໃຊ້ | ແກ້ໄຂ',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsGeometry.all(20),
                  child: Column(
                    children: [
                      TextFiledWidget(
                        label: 'ຊື່ ແລະ ນາມສະກຸນ',
                        controller: fullNameController,
                      ),
                      Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ຊື່ຜູ້ໃຊ້',
                              controller: usernameController,
                            ),
                          ),
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ລະຫັດຜ່ານ',
                              controller: passwordControlelr,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropDownWidget(
                              label: 'ສາຂາ',
                              items: ['TCR_VTE', 'TCR_PAKSE01', 'TCR_PAKSE02'],
                              onChanged: (value) {
                                setState(() {
                                  branchSelected = value;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: DropDownWidget(
                              label: 'ສິດໃຊ້ງານ',
                              items: [
                                'IT',
                                'PURCHASER',
                                'DISTRICT_MANAGER',
                                'DIRECTOR',
                              ],
                              onChanged: (value) {
                                setState(() {
                                  roleSelected = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        spacing: 10,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade500,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('ຍົກເລີກ')),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final fullName = fullNameController.text.trim();
                              final username = usernameController.text.trim();
                              final password = passwordControlelr.text.trim();
                              final branch = branchSelected;
                              final role = roleSelected;

                              context.read<UserProvider>().addUser(
                                fullName,
                                username,
                                password,
                                branch.toString(),
                                role.toString(),
                              );

                              Navigator.pop(context);
                            },
                            child: Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: ColorService().mainGredientColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'ບັນທຶກ',
                                  style: TextStyle(color: Colors.white),
                                ),
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
        ),
      ],
    );
  }
}
