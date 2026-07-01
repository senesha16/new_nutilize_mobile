import 'package:flutter/material.dart';

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({super.key, this.selectedIndex = 0, this.onTap});

  final int selectedIndex;
  final ValueChanged<int>? onTap;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  int? _pressedIndex;

  void _setPressedIndex(int? index) {
    if (_pressedIndex == index) return;
    setState(() {
      _pressedIndex = index;
    });
  }

  static const List<_NavItemData> _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.calendar_month_outlined, label: 'Calendar'),
    _NavItemData(icon: Icons.post_add_outlined, label: 'Request'),
    _NavItemData(icon: Icons.person_outline_rounded, label: 'User'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Color(0xFF35489A),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final bool isSelected = widget.selectedIndex == index;
          return Semantics(
            button: true,
            selected: isSelected,
            label: item.label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white24,
                onTapDown: widget.onTap == null
                    ? null
                    : (_) => _setPressedIndex(index),
                onTapCancel: widget.onTap == null
                    ? null
                    : () => _setPressedIndex(null),
                onTapUp: widget.onTap == null
                    ? null
                    : (_) => _setPressedIndex(null),
                onTap: widget.onTap == null
                    ? null
                    : () {
                        _setPressedIndex(null);
                        widget.onTap!(index);
                      },
                child: AnimatedScale(
                  scale: _pressedIndex == index ? 0.96 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: _NavItem(
                      icon: item.icon,
                      label: item.label,
                      selected: isSelected,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
