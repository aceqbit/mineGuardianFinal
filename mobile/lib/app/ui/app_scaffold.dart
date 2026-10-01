import 'package:flutter/material.dart';

import '../responsive.dart';
import '../theme/tokens.dart';

class NavDest {
  const NavDest({required this.label, required this.icon, this.badge = 0});
  final String label;
  final IconData icon;
  final int badge;
}

/// Bottom bar on compact, rail on medium, permanent ink900 side navigation on expanded.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.destinations = const [],
    this.selectedIndex = 0,
    this.onSelect,
    this.actions = const [],
    this.floatingActionButton,
    this.banner,
    this.leadingHeader,
  });

  final Widget body;
  final String? title;
  final List<NavDest> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final Widget? banner;
  final Widget? leadingHeader;

  Widget _icon(NavDest d, {Color? color}) {
    final i = Icon(d.icon, color: color);
    return d.badge > 0 ? Badge.count(count: d.badge, child: i) : i;
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final size = context.sizeClass;
    final content = Column(children: [?banner, Expanded(child: body)]);
    final appBar = (title != null || actions.isNotEmpty) && size != SizeClass.expanded
        ? AppBar(title: title == null ? null : Text(title!), actions: actions)
        : null;

    if (destinations.isEmpty) {
      return Scaffold(appBar: title == null && actions.isEmpty ? null : AppBar(title: title == null ? null : Text(title!), actions: actions), body: content, floatingActionButton: floatingActionButton);
    }

    if (size == SizeClass.compact) {
      return Scaffold(
        appBar: appBar,
        body: content,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          backgroundColor: c.surface,
          indicatorColor: c.amber50,
          destinations: [for (final d in destinations) NavigationDestination(icon: _icon(d), label: d.label)],
        ),
      );
    }

    if (size == SizeClass.medium) {
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Row(children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.all,
            backgroundColor: c.surface,
            indicatorColor: c.amber50,
            destinations: [for (final d in destinations) NavigationRailDestination(icon: _icon(d), label: Text(d.label))],
          ),
          VerticalDivider(width: 1, color: c.border),
          Expanded(child: content),
        ]),
      );
    }

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Row(children: [
        Container(
          width: 248,
          color: c.ink900,
          child: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.all(Space.x2),
                child: Row(children: [
                  Icon(Icons.shield, color: c.amber500),
                  const SizedBox(width: Space.md),
                  Text('Mine Guardian', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                ]),
              ),
              ?leadingHeader,
              Expanded(
                child: ListView(padding: const EdgeInsets.symmetric(horizontal: Space.md), children: [
                  for (var i = 0; i < destinations.length; i++)
                    _SideItem(dest: destinations[i], selected: i == selectedIndex, onTap: () => onSelect?.call(i), iconBuilder: _icon),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(
          child: Column(children: [
            if (title != null || actions.isNotEmpty)
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
                child: Row(children: [
                  Expanded(child: Text(title ?? '', style: Theme.of(context).textTheme.headlineSmall)),
                  ...actions,
                ]),
              ),
            Expanded(child: content),
          ]),
        ),
      ]),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.dest, required this.selected, required this.onTap, required this.iconBuilder});
  final NavDest dest;
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(NavDest, {Color? color}) iconBuilder;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fg = selected ? c.amber500 : c.slate300;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Material(
        color: selected ? c.ink700 : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
            child: Row(children: [
              iconBuilder(dest, color: fg),
              const SizedBox(width: Space.md),
              Expanded(child: Text(dest.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg))),
            ]),
          ),
        ),
      ),
    );
  }
}
