import 'package:flutter/material.dart';
import 'package:purchaser_edge/services/color_service.dart';

class AppBarWidget extends StatefulWidget {
  const AppBarWidget({required this.label, required this.widget, super.key});

  final String label;
  final Widget widget;

  @override
  State<AppBarWidget> createState() => _AppBarWidgetState();
}

class _AppBarWidgetState extends State<AppBarWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(color: Colors.transparent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColorService().mainTextColor,
            ),
          ),
          widget.widget,
        ],
      ),
    );
  }
}
