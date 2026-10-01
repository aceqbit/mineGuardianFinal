import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';
import '../data/countries.dart';

/// Remembered for the running session only; used for the "Suggested" group, never to pre-select.
class RecentCountry {
  static String? iso;
}

class CountryCodePicker extends StatelessWidget {
  const CountryCodePicker({super.key, required this.value, required this.onChanged, this.focusNode, this.hasError = false});
  final Country? value;
  final ValueChanged<Country> onChanged;
  final FocusNode? focusNode;
  final bool hasError;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    Country? picked;
    if (context.isCompact) {
      picked = await showModalBottomSheet<Country>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        transitionAnimationController: null,
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: CountryList(selected: value)),
      );
    } else {
      picked = await showGeneralDialog<Country>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: Colors.transparent,
        transitionDuration: Motion.of(context, Motion.base),
        pageBuilder: (ctx, _, _) {
          final screen = MediaQuery.sizeOf(ctx);
          final top = (origin.dy + box.size.height + 4).clamp(8.0, (screen.height - 428).clamp(8.0, double.infinity));
          final left = origin.dx.clamp(8.0, (screen.width - 368).clamp(8.0, double.infinity));
          return Stack(children: [
            Positioned(
              top: top,
              left: left,
              width: 360,
              height: 420,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(Radii.card),
                clipBehavior: Clip.antiAlias,
                child: CountryList(selected: value),
              ),
            ),
          ]);
        },
        transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
      );
    }
    if (picked != null) {
      RecentCountry.iso = picked.isoCode;
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: value == null ? 'Select country code' : 'Country code ${value!.name} plus ${value!.dialCode}',
      excludeSemantics: true,
      child: SizedBox(
        width: 112,
        height: 56,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm), side: BorderSide(color: hasError ? c.danger : c.border)),
          child: InkWell(
            focusNode: focusNode,
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.base),
                    child: Text(value?.label ?? 'Code', key: ValueKey(value?.isoCode), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge?.copyWith(color: value == null ? c.muted : c.text)),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: c.muted),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class CountryList extends StatefulWidget {
  const CountryList({super.key, this.selected});
  final Country? selected;

  @override
  State<CountryList> createState() => _CountryListState();
}

class _Row {
  const _Row.header(this.letter) : country = null;
  const _Row.item(this.country) : letter = null;
  final String? letter;
  final Country? country;
}

class _CountryListState extends State<CountryList> {
  static const double _itemH = 52;
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String _q = '';
  int _hi = 0;

  List<Country> get _sorted => [...countries]..sort((a, b) => a.name.compareTo(b.name));

  List<Country> get _filtered {
    final q = _q.trim().toLowerCase().replaceAll('+', '');
    if (q.isEmpty) return _sorted;
    return _sorted.where((c) => c.name.toLowerCase().contains(q) || c.isoCode.toLowerCase() == q || c.dialCode.startsWith(q)).toList();
  }

  List<Country> get _suggested {
    final out = <Country>[];
    final india = countryByIso('IN');
    final recent = countryByIso(RecentCountry.iso);
    if (india != null) out.add(india);
    if (recent != null && recent != india) out.add(recent);
    return out;
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(Country c) => Navigator.of(context).pop(c);

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final list = _filtered;
    if (list.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _hi = (_hi + 1).clamp(0, list.length - 1));
      _ensureVisible();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _hi = (_hi - 1).clamp(0, list.length - 1));
      _ensureVisible();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _select(list[_hi.clamp(0, list.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _ensureVisible() {
    if (!_scroll.hasClients || _q.trim().isEmpty) return;
    final top = _hi * _itemH;
    final vp = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (top + _itemH > _scroll.offset + vp) {
      _scroll.jumpTo(top + _itemH - vp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final list = _filtered;
    final searching = _q.trim().isNotEmpty;

    Widget tile(Country ct, {bool highlighted = false}) => InkWell(
          onTap: () => _select(ct),
          child: Container(
            height: _itemH,
            color: highlighted ? c.amber50 : null,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(children: [
              Text(ct.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: Space.md),
              Expanded(child: Text(ct.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge)),
              Text('+${ct.dialCode}', style: t.bodySmall),
              if (widget.selected == ct) Padding(padding: const EdgeInsets.only(left: Space.sm), child: Icon(Icons.check, size: 18, color: c.success)),
            ]),
          ),
        );

    final rows = <_Row>[];
    if (!searching) {
      String? last;
      for (final ct in list) {
        final l = ct.name[0].toUpperCase();
        if (l != last) {
          rows.add(_Row.header(l));
          last = l;
        }
        rows.add(_Row.item(ct));
      }
    }

    return Container(
      color: c.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Focus(
            onKeyEvent: _onKey,
            child: TextField(
              controller: _search,
              focusNode: _focus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (v) => setState(() {
                _q = v;
                _hi = 0;
              }),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search country, ISO or dial code'),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No matching country', style: t.bodySmall))
              : searching
                  ? ListView.builder(controller: _scroll, itemExtent: _itemH, itemCount: list.length, itemBuilder: (_, i) => tile(list[i], highlighted: i == _hi))
                  : CustomScrollView(controller: _scroll, slivers: [
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xs), child: Text('SUGGESTED', style: t.labelSmall))),
                      SliverList(delegate: SliverChildListDelegate([for (final s in _suggested) tile(s)])),
                      for (final group in _groups(rows))
                        SliverMainAxisGroup(slivers: [
                          SliverPersistentHeader(pinned: true, delegate: _LetterHeader(group.$1, c, t)),
                          SliverList(delegate: SliverChildBuilderDelegate((_, i) => tile(group.$2[i]), childCount: group.$2.length)),
                        ]),
                    ]),
        ),
      ]),
    );
  }

  List<(String, List<Country>)> _groups(List<_Row> rows) {
    final out = <(String, List<Country>)>[];
    for (final r in rows) {
      if (r.letter != null) {
        out.add((r.letter!, <Country>[]));
      } else {
        out.last.$2.add(r.country!);
      }
    }
    return out;
  }
}

class _LetterHeader extends SliverPersistentHeaderDelegate {
  _LetterHeader(this.letter, this.c, this.t);
  final String letter;
  final MgColors c;
  final TextTheme t;

  @override
  double get minExtent => 28;
  @override
  double get maxExtent => 28;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: c.slate100.withValues(alpha: 1),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: Text(letter, style: t.labelLarge?.copyWith(color: Colors.black87)),
      );

  @override
  bool shouldRebuild(covariant _LetterHeader old) => old.letter != letter || old.c != c;
}
