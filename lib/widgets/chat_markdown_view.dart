import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';

/// Lightweight, robust Markdown-style text renderer for AI responses.
/// Parses **bold**, *italics*, bullet points, numbered lists, and headers.
class ChatMarkdownView extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const ChatMarkdownView({
    super.key,
    required this.text,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final defaultStyle = baseStyle ??
        AppTextStyles.bodyMedium.copyWith(
          color: AppColors.darkText,
          height: 1.5,
          fontSize: 14.5,
        );

    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Headers: ### or ## or #
      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              trimmed.substring(4),
              style: AppTextStyles.heading3.copyWith(
                fontSize: 16,
                color: AppColors.darkText,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              trimmed.substring(3),
              style: AppTextStyles.heading2.copyWith(
                fontSize: 17,
                color: AppColors.darkText,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              trimmed.substring(2),
              style: AppTextStyles.heading1.copyWith(
                fontSize: 18,
                color: AppColors.darkText,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('* ') ||
          trimmed.startsWith('- ') ||
          trimmed.startsWith('• ')) {
        // Bullet points
        final bulletContent = trimmed.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 8),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _buildRichText(bulletContent, defaultStyle),
                ),
              ],
            ),
          ),
        );
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        // Numbered list
        final match = RegExp(r'^(\d+\.)\s*(.*)$').firstMatch(trimmed);
        if (match != null) {
          final numberPart = match.group(1)!;
          final contentPart = match.group(2)!;
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$numberPart ',
                    style: defaultStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildRichText(contentPart, defaultStyle),
                  ),
                ],
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildRichText(line, defaultStyle),
            ),
          );
        }
      } else {
        // Regular paragraph line
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildRichText(line, defaultStyle),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parses **bold** and *italic* tokens within a line of text.
  Widget _buildRichText(String text, TextStyle defaultStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*([^*]+)\*\*)|(\*([^*]+)\*)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: defaultStyle,
          ),
        );
      }

      if (match.group(2) != null) {
        // Bold: **text**
        spans.add(
          TextSpan(
            text: match.group(2),
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        );
      } else if (match.group(4) != null) {
        // Italic: *text*
        spans.add(
          TextSpan(
            text: match.group(4),
            style: defaultStyle.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: defaultStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
