import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class ColorService {
  final mainGredientColor = LinearGradient(
    colors: [Colors.blue.shade700, Colors.blue.shade900],
    begin: AlignmentGeometry.topLeft,
    end: AlignmentGeometry.bottomRight
  );
  final mainBackGroundColor = HexColor('#E6E9F0');
  final mainTextColor = Colors.grey[800];

  final primaryColor = HexColor('#277AE2');
  final warningColor = HexColor('#Fc9744');
  final successColor = HexColor('#068D3E');
  final errorColor = HexColor('#D83236');

  final mainTextFiledColor = Colors.grey.shade200;
  final borderTextFiledColor = Colors.grey.shade300;
}
