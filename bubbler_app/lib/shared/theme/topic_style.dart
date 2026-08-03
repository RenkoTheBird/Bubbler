import 'package:flutter/material.dart';

/// Topic accent colors and Material icons (replaces SF Symbols in Swift
/// `TopicStyle` from `TopicPicker.swift`).
abstract final class TopicStyle {
  static IconData icon(String topic) {
    switch (topic.toLowerCase()) {
      case 'technology':
        return Icons.computer;
      case 'science':
        return Icons.public;
      case 'sports':
        return Icons.sports_basketball;
      case 'politics':
        return Icons.account_balance;
      case 'entertainment':
        return Icons.movie;
      case 'business':
        return Icons.work;
      case 'health':
        return Icons.favorite;
      case 'education':
        return Icons.menu_book;
      case 'environment':
        return Icons.eco;
      default:
        return Icons.grid_view;
    }
  }

  static Color color(String topic) {
    switch (topic.toLowerCase()) {
      case 'technology':
        return Colors.blue;
      case 'science':
        return Colors.purple;
      case 'sports':
        return Colors.green;
      case 'politics':
        return Colors.red;
      case 'entertainment':
        return Colors.pink;
      case 'business':
        return Colors.indigo;
      case 'health':
        return const Color(0xFF00C7BE); // Swift `.mint`
      case 'education':
        return Colors.orange;
      case 'environment':
        return Colors.teal;
      default:
        return Colors.cyan;
    }
  }
}
