import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'is_cupertino.dart';

/// Tab destination for [AdaptiveTabScaffold].
class AdaptiveTabDestination {
  const AdaptiveTabDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// Bottom tabs — [CupertinoTabScaffold] on iOS/macOS, Material elsewhere.
///
/// Each tab is wrapped in its own [Navigator] (Cupertino via [CupertinoTabView])
/// so pushes like Create Post stay above the tab bar, matching Swift
/// `NavigationStack` per tab.
class AdaptiveTabScaffold extends StatefulWidget {
  const AdaptiveTabScaffold({
    super.key,
    required this.destinations,
    required this.tabBuilder,
    this.activeColor,
    this.backgroundColor,
  });

  final List<AdaptiveTabDestination> destinations;
  final IndexedWidgetBuilder tabBuilder;
  final Color? activeColor;
  final Color? backgroundColor;

  @override
  State<AdaptiveTabScaffold> createState() => _AdaptiveTabScaffoldState();
}

class _AdaptiveTabScaffoldState extends State<AdaptiveTabScaffold> {
  int _index = 0;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;

  @override
  void initState() {
    super.initState();
    _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      widget.destinations.length,
      (_) => GlobalKey<NavigatorState>(),
    );
  }

  @override
  void didUpdateWidget(covariant AdaptiveTabScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinations.length != widget.destinations.length) {
      _navigatorKeys
        ..clear()
        ..addAll(
          List<GlobalKey<NavigatorState>>.generate(
            widget.destinations.length,
            (_) => GlobalKey<NavigatorState>(),
          ),
        );
      if (_index >= widget.destinations.length) {
        _index = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.destinations.isNotEmpty);
    if (isCupertinoPlatform(context)) {
      return _buildCupertino(context);
    }
    return _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    final active = widget.activeColor ?? CupertinoColors.activeBlue;
    return CupertinoTabScaffold(
      backgroundColor: widget.backgroundColor ?? Colors.transparent,
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xE60D47A1),
        activeColor: active,
        inactiveColor: Colors.white.withValues(alpha: 0.55),
        items: [
          for (final destination in widget.destinations)
            BottomNavigationBarItem(
              icon: Icon(destination.icon),
              activeIcon: Icon(destination.selectedIcon ?? destination.icon),
              label: destination.label,
            ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => widget.tabBuilder(context, index),
        );
      },
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final active = widget.activeColor ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: widget.backgroundColor ?? Colors.transparent,
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < widget.destinations.length; i++)
            Navigator(
              key: _navigatorKeys[i],
              onGenerateRoute: (settings) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (context) => widget.tabBuilder(context, i),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
        },
        backgroundColor: const Color(0xE60D47A1),
        indicatorColor: Colors.white.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final destination in widget.destinations)
            NavigationDestination(
              icon: Icon(
                destination.icon,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              selectedIcon: Icon(
                destination.selectedIcon ?? destination.icon,
                color: active,
              ),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
