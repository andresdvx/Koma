import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

class DockItem {
  const DockItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Dock flotante de cristal: la opción activa se expande con su etiqueta.
class Dock extends StatelessWidget {
  const Dock({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.glass,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _DockButton(
                    item: items[i],
                    selected: i == index,
                    onTap: () {
                      if (i != index) HapticFeedback.selectionClick();
                      onSelect(i);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        padding: EdgeInsets.symmetric(horizontal: selected ? 20 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 22, color: selected ? Colors.white : c.muted),
            AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
