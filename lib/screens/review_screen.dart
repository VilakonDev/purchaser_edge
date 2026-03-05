import 'package:flutter/material.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:unicons/unicons.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: ColorService().mainGredientColor,
            ),
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () {
                    Future.microtask(() {
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Icon(UniconsLine.arrow_left),
                        Text(
                          'ກັບຄືນ',
                          style: TextStyle(color: ColorService().mainTextColor),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'ກວດສອບເອກະສານກ່ອນສົ່ງ',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(width: 100),
                // Action Buttons
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ColorService().mainBackGroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
