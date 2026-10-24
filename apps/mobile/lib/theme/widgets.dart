import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';

/// Shared brand mark (moon + label) for tab headers and page headers.
/// Keep one style so IndexedStack tab switches do not jump.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.label,
  });

  /// When null, uses [AppLocalizations.appTitle].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? AppLocalizations.of(context).appTitle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.nightlight_round,
          size: 16,
          color: AppColors.primary.withValues(alpha: 0.95),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primarySoft,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
  });

  /// When null, [BrandMark] falls back to [AppLocalizations.appTitle].
  final String? eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandMark(label: eyebrow),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.outlineSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.paperShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: AppColors.lanternGlow,
            blurRadius: 40,
            offset: Offset(0, 16),
            spreadRadius: -8,
          ),
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
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
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, size: 14, color: AppColors.onPrimary),
          ],
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfacePaperLayered,
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : const Color(0x40C38D9E),
      ),
      // Keep chip rows flush with section labels (default M3 padding indents).
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    );
  }
}

/// Unfocus and wait until soft-keyboard insets settle (or timeout).
///
/// Use before anchored overlays / pickers so they measure the post-keyboard
/// field position instead of the raised-sheet position.
Future<void> waitForKeyboardDismissed(BuildContext context) async {
  FocusScope.of(context).unfocus();
  final started = DateTime.now();
  while (context.mounted &&
      MediaQuery.viewInsetsOf(context).bottom > 0 &&
      DateTime.now().difference(started) < const Duration(milliseconds: 400)) {
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }
  if (!context.mounted) return;
  await Future<void>.delayed(const Duration(milliseconds: 48));
}

/// Form-looking select that waits for the keyboard to dismiss before opening
/// a menu, so the overlay anchors to the settled field position.
class SoftSelectField<T> extends StatefulWidget {
  const SoftSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  /// When null, uses [AppLocalizations.commonPleaseSelect].
  final String? placeholder;

  @override
  State<SoftSelectField<T>> createState() => _SoftSelectFieldState<T>();
}

class _SoftSelectFieldState<T> extends State<SoftSelectField<T>> {
  late final FocusNode _focusNode;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'SoftSelectField');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// Clear focus after the menu route restores it, so no TextField reclaims
  /// focus (and the keyboard stays dismissed).
  void _clearFocusAfterMenu() {
    if (!mounted) return;
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    });
  }

  String? get _matchedLabel {
    for (final (v, text) in widget.options) {
      if (v == widget.value) return text;
    }
    return null;
  }

  Future<void> _open() async {
    if (_opening || widget.options.isEmpty) return;
    _opening = true;
    try {
      await waitForKeyboardDismissed(context);
      if (!mounted) return;

      // Own focus before the menu route pushes, so dismiss restores here
      // instead of the previous TextField (which would reopen the keyboard).
      _focusNode.requestFocus();

      final box = context.findRenderObject() as RenderBox?;
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (box == null || overlay == null || !box.hasSize) return;

      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      final bottomRight = box.localToGlobal(
        box.size.bottomRight(Offset.zero),
        ancestor: overlay,
      );
      final position = RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      );

      final picked = await showMenu<T>(
        context: context,
        position: position,
        constraints: BoxConstraints(
          minWidth: box.size.width,
          maxWidth: box.size.width,
        ),
        items: [
          for (final (v, text) in widget.options)
            PopupMenuItem<T>(
              value: v,
              child: Text(
                text,
                style: TextStyle(
                  fontWeight:
                      v == widget.value ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.onSurface,
                ),
              ),
            ),
        ],
      );
      if (!mounted) return;
      if (picked != null) widget.onChanged(picked);
      _clearFocusAfterMenu();
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched = _matchedLabel;
    final valid = matched != null;
    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: _open,
        child: InputDecorator(
          isEmpty: !valid,
          isFocused: _focusNode.hasFocus,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: const Icon(
              Icons.arrow_drop_down,
              color: AppColors.onSurfaceMuted,
            ),
          ),
          child: Text(
            matched ??
                widget.placeholder ??
                AppLocalizations.of(context).commonPleaseSelect,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  height: 1.25,
                  color: valid ? AppColors.onSurface : AppColors.onSurfaceMuted,
                ),
          ),
        ),
      ),
    );
  }
}

class AmberCta extends StatelessWidget {
  const AmberCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.local_library_outlined,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFE8A87C),
                  Color(0xFFF4B251),
                ],
              ),
        color: onPressed == null ? AppColors.surfaceHighest : null,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  busy ? Icons.hourglass_top : icon,
                  color: onPressed == null
                      ? AppColors.onSurfaceDim
                      : AppColors.onPrimary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: onPressed == null
                        ? AppColors.onSurfaceDim
                        : AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                    colors: [Color(0xFF2A3A4F), Color(0xFF3A2A22)],
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
                  tooltip: AppLocalizations.of(context)
                      .storiesContinueEpisodeTooltip,
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
