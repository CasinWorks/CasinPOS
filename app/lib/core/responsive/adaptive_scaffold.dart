import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'breakpoints.dart';

typedef ShellDestination = ({String id, String label, IconData icon, int? badge});

/// Responsive shell: phone bottom nav, tablet/desktop sidebar (+ optional cart).
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    required this.body,
    this.cartTray,
    this.brandHeader,
    this.footer,
  });

  final List<ShellDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Widget body;
  final Widget? cartTray;
  final Widget? brandHeader;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showSidebar = Breakpoints.useSidebar(width);
        final showCart = cartTray != null && Breakpoints.useCartTray(width);

        if (!showSidebar) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _indexOf(selectedId),
              onDestinationSelected: (i) => onSelect(destinations[i].id),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: AppSpacing.sidebarWidth,
                child: _Sidebar(
                  destinations: destinations,
                  selectedId: selectedId,
                  onSelect: onSelect,
                  brandHeader: brandHeader,
                  footer: footer,
                ),
              ),
              Expanded(child: body),
              if (showCart)
                SizedBox(
                  width: AppSpacing.cartTrayWidth,
                  child: cartTray,
                ),
            ],
          ),
        );
      },
    );
  }

  int _indexOf(String id) {
    final i = destinations.indexWhere((d) => d.id == id);
    return i < 0 ? 0 : i;
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    this.brandHeader,
    this.footer,
  });

  final List<ShellDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Widget? brandHeader;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scaffold,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.slate200)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (brandHeader != null) ...[
                brandHeader!,
                const SizedBox(height: AppSpacing.lg),
              ],
              Expanded(
                child: ListView(
                  children: [
                    for (final d in destinations)
                      _NavTile(
                        label: d.label,
                        icon: d.icon,
                        selected: d.id == selectedId,
                        badge: d.badge,
                        onTap: () => onSelect(d.id),
                      ),
                  ],
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.slate900 : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.slate500,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? Colors.white : AppColors.slate600,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.restaurant : AppColors.slate200,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.slate700,
                      ),
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
