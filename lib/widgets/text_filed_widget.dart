import 'package:flutter/material.dart';
import 'package:purchaser_edge/services/color_service.dart';

class TextFiledWidget extends StatefulWidget {
  const TextFiledWidget({required this.label,required this.isHidden,required this.controller,super.key});

  final String label;
  final bool isHidden;
  final TextEditingController controller;

  @override
  State<TextFiledWidget> createState() => _TextFiledWidgetState();
}

class _TextFiledWidgetState extends State<TextFiledWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          height: 40,
          child: Center(
            child: Align(
              alignment: AlignmentGeometry.centerStart,
              child: Text(widget.label),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: TextField(
            obscureText: widget.isHidden,
            controller: widget.controller,
            decoration: InputDecoration(
              filled: true,
              contentPadding: EdgeInsets.all(5),
              fillColor: ColorService().mainTextFiledColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(
                  color: ColorService().borderTextFiledColor,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(
                  color: ColorService().borderTextFiledColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
