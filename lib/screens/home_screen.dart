import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/main.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/screens/pages/all_document_page.dart';
import 'package:purchaser_edge/screens/pages/create_purchase_order_page.dart';
import 'package:purchaser_edge/screens/pages/dashboard_page.dart';
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

  List<Widget> _pages = [
    DashBoardPage(),
    CreatePurchaseOrderPage(),
    AllDocumentPage(),
    DashBoardPage(),
  ];

  @override
  Widget build(BuildContext context) {
    context.read<DocumentProvider>().startAutoFetch();

    return Scaffold(
      body: Row(
        children: [
          _buildSideBar(),
          Expanded(child: _pages[currentPageIndex]),
        ],
      ),
    );
  }

  Widget _buildSideBar() {
    Widget _buildSideBarMenu(int index, IconData icon, String label) {
      return GestureDetector(
        onTap: () {
          setState(() {
            currentPageIndex = index;
          });
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(),
          child: Row(
            spacing: isShowLabel ? 10 : 0,
            children: [
              Icon(icon, color: Colors.white),

              isShowLabel
                  ? Text(
                      label,
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    )
                  : SizedBox(),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: ColorService().mainGredientColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    isShowLabel = !isShowLabel;
                  });
                },
                child: Container(
                  height: 50,
                  child: Row(
                    spacing: 10,
                    children: [Icon(UniconsLine.bars, color: Colors.white)],
                  ),
                ),
              ),

              _buildSideBarMenu(0, UniconsLine.create_dashboard, 'ໜ້າຫຼັກ'),
              _buildSideBarMenu(1, UniconsLine.plus_circle, 'ສ້າງເອກະສານໃຫມ່'),
              _buildSideBarMenu(2, UniconsLine.file_alt, 'ເອກະສານທັງໝົດ'),
            ],
          ),

          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => MyApp()),
                (predicate) => false,
              );
            },
            child: Container(
              height: 50,
              child: Row(
                spacing: isShowLabel ? 10 : 0,
                children: [
                  Icon(UniconsLine.sign_in_alt, color: Colors.white),

                  isShowLabel
                      ? Text(
                          'ອອກຈາກລະບົບ',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        )
                      : SizedBox(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
