// lib/widgets/selection_bottom_sheet.dart
//
// Modal bottom-sheet pickers adhering to Android settings guidelines:
// Displays full readable option titles, native scripts, descriptions, and radio-style checks.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SelectionItem<T> {
  final T value;
  final String title;
  final String? subtitle;
  final Widget? trailingBadge;

  const SelectionItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.trailingBadge,
  });
}

Future<T?> showSelectionBottomSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<SelectionItem<T>> items,
  required T selectedValue,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.borderLight),

              // Option list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.borderLight,
                  ),
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    final isSelected = item.value == selectedValue;

                    return InkWell(
                      onTap: () => Navigator.pop(ctx, item.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.title,
                                          style: AppTypography.bodyMedium.copyWith(
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (item.trailingBadge != null) ...[
                                        const SizedBox(width: 8),
                                        item.trailingBadge!,
                                      ],
                                    ],
                                  ),
                                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      item.subtitle!,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryBlue : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
