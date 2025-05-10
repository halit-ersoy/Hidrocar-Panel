import 'package:flutter/material.dart';

class Elements {
  Widget crossText({
    required double? right,
    required double? left,
    required double? top,
    required double? bottom,
    required CrossAxisAlignment locate,
    required List<String> titleTexts,
    required List<String> valueTexts,
  }) {
    const titleTextStyle = TextStyle(
        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold);
    const valueTextStyle = TextStyle(color: Colors.white, fontSize: 18);

    return Positioned(
      right: right,
      left: left,
      top: top,
      bottom: bottom,
      child: Column(
        crossAxisAlignment: locate,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          titleTexts.length,
          (index) => Column(
            crossAxisAlignment: locate,
            children: [
              Text(titleTexts[index], style: titleTextStyle),
              Text(valueTexts[index], style: valueTextStyle),
            ],
          ),
        ),
      ),
    );
  }
}
