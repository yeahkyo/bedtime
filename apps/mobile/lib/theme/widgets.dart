import 'package:flutter/material.dart';

import 'app_theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.nightlight_round, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primarySoft,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.outline),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 0, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.onPrimary : const Color(0xFFE5DCBA),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFF1B2E33),
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFF3A5248),
      ),
      // Keep chip rows flush with section labels (default M3 padding indents).
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    );
  }
}

class AmberCta extends StatelessWidget {
  const AmberCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.auto_stories,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: onPressed == null
            ? null
            : const [
                BoxShadow(
                  color: AppColors.lanternGlow,
                  blurRadius: 22,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(busy ? Icons.hourglass_top : icon),
        label: Text(label),
      ),
    );
  }
}

class LibraryStoryTile extends StatelessWidget {
  const LibraryStoryTile({
    super.key,
    required this.title,
    required this.meta,
    required this.onPlay,
    this.onContinue,
    this.onRetry,
    this.failed = false,
  });

  final String title;
  final String meta;
  final VoidCallback onPlay;
  final VoidCallback? onContinue;
  final VoidCallback? onRetry;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final primaryAction = failed && onRetry != null ? onRetry! : onPlay;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: primaryAction,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: failed ? AppColors.secondary.withValues(alpha: 0.45) : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A3A4F), Color(0xFF164F4A)],
                  ),
                ),
                child: Icon(
                  failed ? Icons.error_outline_rounded : Icons.menu_book_rounded,
                  color: failed ? AppColors.secondary : AppColors.primarySoft,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(meta, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (onContinue != null)
                IconButton(
                  tooltip: '续写下一集',
                  onPressed: onContinue,
                  icon: const Icon(Icons.playlist_add, color: AppColors.secondary),
                ),
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: primaryAction,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      failed ? Icons.refresh_rounded : Icons.play_arrow_rounded,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
