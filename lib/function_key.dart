import 'package:flutter/material.dart';

class FunctionKey extends StatelessWidget {
  final String label;
  final String description;
  final bool isActive;

  const FunctionKey({super.key,
    required this.label,
    required this.description,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          description,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
