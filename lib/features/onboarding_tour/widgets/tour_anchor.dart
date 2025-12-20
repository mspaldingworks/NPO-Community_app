import 'package:flutter/widgets.dart';
import 'package:transconnect/features/onboarding_tour/services/tour_anchor_registry.dart';

class TourAnchor extends StatefulWidget {
  final String name;
  final Widget child;

  const TourAnchor({
    super.key,
    required this.name,
    required this.child,
  });

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  late GlobalKey _anchorKey;

  @override
  void initState() {
    super.initState();
    _anchorKey = GlobalKey(debugLabel: 'tour_anchor:${widget.name}');
    TourAnchorRegistry.instance.register(widget.name, _anchorKey);
  }

  @override
  void didUpdateWidget(covariant TourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      TourAnchorRegistry.instance.unregister(oldWidget.name, _anchorKey);
      _anchorKey = GlobalKey(debugLabel: 'tour_anchor:${widget.name}');
      TourAnchorRegistry.instance.register(widget.name, _anchorKey);
    }
  }

  @override
  void dispose() {
    TourAnchorRegistry.instance.unregister(widget.name, _anchorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _anchorKey,
      child: widget.child,
    );
  }
}
