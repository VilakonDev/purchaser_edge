import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/main.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/user_provider.dart';
import 'package:purchaser_edge/screens/pages/all_document_page.dart';
import 'package:purchaser_edge/screens/pages/approve_document_page.dart';
import 'package:purchaser_edge/screens/pages/create_purchase_order_page.dart';
import 'package:purchaser_edge/screens/pages/dashboard_page.dart';
import 'package:purchaser_edge/screens/pages/user_management_page.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:unicons/unicons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isShowLabel = false;
  int currentPageIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashBoardPage(),
      CreatePurchaseOrderPage(),
      AllDocumentPage(),
      UserManagementPage(),
      ApproveDocumentPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().startAutoFetchDocument();
      context.read<UserProvider>().startAutoFetchUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    final role = currentUser.role;

    return Scaffold(
      body: Row(
        children: [
          _buildSideBar(role),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  width: double.infinity,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorService().mainBackGroundColor,
                  ),
                  child: Row(
                    children: [
                      Icon(UniconsLine.user_circle, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        currentUser.fullName,
                        style: TextStyle(
                          color: ColorService().mainTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ColorService().primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ColorService().primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: currentPageIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBar(String role) {
    Widget buildMenu(int index, IconData icon, String label) {
      final isActive = currentPageIndex == index;

      return GestureDetector(
        onTap: () => setState(() => currentPageIndex = index),
        child: Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 20,
              ),
              if (isShowLabel) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isShowLabel ? 200 : 60,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(gradient: ColorService().mainGredientColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle button
              GestureDetector(
                onTap: () => setState(() => isShowLabel = !isShowLabel),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(
                        isShowLabel
                            ? UniconsLine.bars
                            : UniconsLine.bars,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              buildMenu(0, UniconsLine.create_dashboard, 'ໜ້າຫຼັກ'),
              buildMenu(1, UniconsLine.plus_circle, 'ສ້າງເອກະສານໃຫມ່'),
              buildMenu(2, UniconsLine.file_alt, 'ເອກະສານທັງໝົດ'),
              if (role == "IT")
                buildMenu(3, UniconsLine.users_alt, 'ຜູ້ໃຊ້ງານ'),
              if (role == "DISTRICT_MANAGER" || role == "DIRECTOR")
                buildMenu(4, UniconsLine.check, 'ອະນຸມັດ'),
            ],
          ),

          // Logout
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => MyApp()),
                (predicate) => false,
              );
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    UniconsLine.sign_in_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (isShowLabel) ...[
                    const SizedBox(width: 10),
                    const Text(
                      'ອອກຈາກລະບົບ',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
