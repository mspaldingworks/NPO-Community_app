import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:npo_community/features/meadow/models/online_user.dart';
import 'package:npo_community/widgets/pronoun_butterfly.dart';

class MeadowButterfly extends StatefulWidget {
  const MeadowButterfly({
    super.key,
    required this.user,
    required this.meadowSize,
    required this.padding,
    this.size = 120,
    this.flyToTarget,
    this.onArrived,
    this.onTap,
    this.isLeaving = false,
    this.onFadeOutComplete,
    this.driftEnabled = true,
    this.flightDuration = const Duration(milliseconds: 900),
  });

  final OnlineUser user;
  final Size meadowSize;
  final EdgeInsets padding;
  final double size;
  final Offset? flyToTarget;
  final VoidCallback? onArrived;
  final VoidCallback? onTap;
  final bool isLeaving;
  final VoidCallback? onFadeOutComplete;
  final bool driftEnabled;
  final Duration flightDuration;

  @override
  State<MeadowButterfly> createState() => _MeadowButterflyState();
}

class _MeadowButterflyState extends State<MeadowButterfly>
    with TickerProviderStateMixin {
  late Offset _currentPosition;
  late AnimationController _movementController;
  late AnimationController _fadeController;
  Timer? _pauseTimer;
  Offset? _activeFlightTarget;
  late final Random _random;
  late final double _bobPhase;
  late final Offset _homePosition;
  late final double _wigglePhase;
  int _wiggleCycles = 2;
  double _bobAmplitude = 2.6;
  int _flightCounter = 0;
  bool _hasEntered = false;

  List<double> _pathProgressFractions = <double>[];
  List<double> _pathProgressT = <double>[];
  double _pathTotalLength = 1;

  static const double _pixelsPerSecond = 14;
  static const Duration _minTravelDuration = Duration(milliseconds: 2800);
  static const double _maxRoamRadiusFromHome = 220;

  Offset _start = Offset.zero;
  Offset _control1 = Offset.zero;
  Offset _control2 = Offset.zero;
  Offset _end = Offset.zero;

  @override
  void initState() {
    super.initState();
    _random = Random(
      widget.user.id.hashCode ^ widget.user.lastSeen.millisecondsSinceEpoch,
    );
    _currentPosition = _randomEntryPoint();
    _bobPhase = _random.nextDouble() * pi * 2;
    _wigglePhase = _random.nextDouble() * pi * 2;
    final jitterRandom = Random(widget.user.id.hashCode ^ 0x5a5a5a5a);
    final jitter = Offset(
      (jitterRandom.nextDouble() - 0.5) * 120,
      (jitterRandom.nextDouble() - 0.5) * 120,
    );
    final baseHome = widget.user.position == Offset.zero
        ? _randomPoint()
        : widget.user.position;
    _homePosition = _clampToBounds(baseHome + jitter);
    _movementController = AnimationController(vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _movementController.addListener(_handleTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startEntry();
    });
  }

  @override
  void didUpdateWidget(covariant MeadowButterfly oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLeaving && widget.isLeaving) {
      _pauseTimer?.cancel();
      _movementController.stop();
      _fadeController.reverse().whenComplete(() {
        if (!mounted) return;
        if (!widget.isLeaving) return;
        widget.onFadeOutComplete?.call();
      });
      return;
    }

    if (oldWidget.isLeaving && !widget.isLeaving) {
      _fadeController.forward();
    }

    if (widget.flyToTarget != null &&
        widget.flyToTarget != _activeFlightTarget) {
      _flyTo(widget.flyToTarget!);
    } else if (widget.flyToTarget == null && _activeFlightTarget != null) {
      _activeFlightTarget = null;
      if (widget.driftEnabled) {
        _startDrift();
      }
    } else if (!widget.driftEnabled) {
      _stopDrift();
    } else if (widget.driftEnabled &&
        !_movementController.isAnimating &&
        !(_pauseTimer?.isActive ?? false)) {
      _startDrift();
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _movementController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startEntry() {
    if (_hasEntered) return;
    _hasEntered = true;
    _animateTo(
      _homePosition,
      duration: Duration.zero,
      onCompleted: () {
        if (widget.driftEnabled) {
          _startDrift();
        }
      },
    );
  }

  void _startDrift() {
    if (!widget.driftEnabled || widget.isLeaving) return;
    _pauseTimer?.cancel();
    final target = _random.nextDouble() < 0.08
        ? _randomPoint()
        : _randomNearbyPoint();
    _animateTo(target, duration: Duration.zero);
  }

  void _stopDrift() {
    _pauseTimer?.cancel();
    _movementController.stop();
  }

  void _flyTo(Offset target) {
    _activeFlightTarget = target;
    _pauseTimer?.cancel();
    _animateTo(
      target,
      duration: _durationForDistance(
        _currentPosition,
        target,
        minimum: widget.flightDuration,
      ),
      onCompleted: () {
        widget.onArrived?.call();
      },
    );
  }

  void _animateTo(
    Offset target, {
    required Duration duration,
    VoidCallback? onCompleted,
  }) {
    final flightId = ++_flightCounter;
    final clampedTarget = _clampToBounds(target);
    _movementController
      ..stop()
      ..reset();

    _start = _currentPosition;
    _end = clampedTarget;

    _bobAmplitude = widget.flyToTarget != null ? 1.8 : 2.6;

    final dx = _end.dx - _start.dx;
    final dy = _end.dy - _start.dy;
    final length = max(1.0, sqrt(dx * dx + dy * dy));
    final tx = dx / length;
    final ty = dy / length;
    final nx = -dy / length;
    final ny = dx / length;

    final wobbleBase = min(widget.size * 2.0, length * 0.85);
    final wobble1 = wobbleBase * (0.70 + _random.nextDouble() * 0.70);
    final wobble2 = wobbleBase * (0.50 + _random.nextDouble() * 0.90);
    final sign1 = _random.nextBool() ? 1.0 : -1.0;
    final sign2 =
        (_random.nextBool() ? 1.0 : -1.0) *
        (_random.nextDouble() < 0.65 ? -sign1 : 1.0);
    final loopAmount =
        min(length * 0.28, widget.size * 3.0) *
        (0.25 + _random.nextDouble() * 0.85);

    _control1 = _clampToBounds(
      Offset(
        _start.dx + dx * 0.32 + nx * wobble1 * sign1 - tx * loopAmount,
        _start.dy + dy * 0.32 + ny * wobble1 * sign1 - ty * loopAmount,
      ),
      extra: widget.size * 1.6,
    );
    _control2 = _clampToBounds(
      Offset(
        _start.dx + dx * 0.68 + nx * wobble2 * sign2 + tx * loopAmount,
        _start.dy + dy * 0.68 + ny * wobble2 * sign2 + ty * loopAmount,
      ),
      extra: widget.size * 1.6,
    );

    _buildPathLookup();
    final estimatedDuration = _durationForPathLength(minimum: duration);
    final estimatedSeconds = estimatedDuration.inMilliseconds / 1000.0;
    _wiggleCycles = (estimatedSeconds * 0.7).ceil().clamp(2, 5);

    _buildPathLookup();
    final adjustedDuration = _durationForPathLength(minimum: duration);
    _movementController.duration = adjustedDuration;

    _movementController.forward().whenComplete(() {
      if (!mounted) return;
      if (flightId != _flightCounter) return;
      setState(() {
        _currentPosition = _clampToBounds(_rawPositionAt(1));
      });
      onCompleted?.call();

      if (widget.flyToTarget != null) {
        return;
      }
      if (widget.driftEnabled && !widget.isLeaving) {
        final pause = Duration(milliseconds: 1400 + _random.nextInt(900));
        _pauseTimer?.cancel();
        _pauseTimer = Timer(pause, () {
          if (!mounted) return;
          if (!widget.driftEnabled || widget.isLeaving) return;
          _startDrift();
        });
      }
    });
  }

  void _handleTick() {
    final t = _tForProgress(_movementController.value);
    final next = _rawPositionAt(t);
    if (!mounted) return;
    final minX = widget.padding.left + widget.size / 2;
    final minY = widget.padding.top + widget.size / 2;
    final maxX =
        widget.meadowSize.width - widget.padding.right - widget.size / 2;
    final maxY =
        widget.meadowSize.height - widget.padding.bottom - widget.size / 2;
    setState(() {
      _currentPosition = Offset(
        next.dx.clamp(minX, maxX).toDouble(),
        next.dy.clamp(minY, maxY).toDouble(),
      );
    });
  }

  Offset _rawPositionAt(double t) {
    final point = _cubicBezier(_start, _control1, _control2, _end, t);
    final dx = _end.dx - _start.dx;
    final dy = _end.dy - _start.dy;
    final length = max(1.0, sqrt(dx * dx + dy * dy));
    final tx = dx / length;
    final ty = dy / length;
    final nx = -dy / length;
    final ny = dx / length;
    final envelope = sin(pi * t);
    final wiggleAmplitude = min(widget.size * 1.35, length * 0.18);
    final loopAmplitude = min(widget.size * 0.85, length * 0.12);
    final wiggle =
        sin((t * pi * 2 * _wiggleCycles) + _wigglePhase) *
        wiggleAmplitude *
        envelope;
    final loop =
        sin((t * pi * 2 * _wiggleCycles) + _bobPhase) *
        loopAmplitude *
        envelope;
    final windingPoint = point.translate(
      nx * wiggle + tx * loop,
      ny * wiggle + ty * loop,
    );
    final wistfulBob = sin((t * pi * 2) + _bobPhase) * _bobAmplitude * envelope;
    return windingPoint.translate(0, wistfulBob);
  }

  void _buildPathLookup() {
    const steps = 32;
    final cumulative = <double>[0];
    final ts = <double>[0];
    var total = 0.0;

    var prev = _rawPositionAt(0);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final current = _rawPositionAt(t);
      total += (current - prev).distance;
      cumulative.add(total);
      ts.add(t);
      prev = current;
    }

    _pathTotalLength = max(1.0, total);
    _pathProgressFractions = cumulative
        .map((v) => v / _pathTotalLength)
        .toList();
    _pathProgressT = ts;
  }

  double _tForProgress(double progress) {
    if (_pathProgressFractions.isEmpty || _pathProgressT.isEmpty) {
      return progress;
    }
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;

    var low = 0;
    var high = _pathProgressFractions.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_pathProgressFractions[mid] < progress) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    final idx = low;
    if (idx == 0) return _pathProgressT.first;
    final prevFrac = _pathProgressFractions[idx - 1];
    final nextFrac = _pathProgressFractions[idx];
    final prevT = _pathProgressT[idx - 1];
    final nextT = _pathProgressT[idx];
    final span = max(1e-6, nextFrac - prevFrac);
    final local = ((progress - prevFrac) / span).clamp(0.0, 1.0);
    return prevT + (nextT - prevT) * local;
  }

  Duration _durationForPathLength({required Duration minimum}) {
    final ms = (_pathTotalLength / _pixelsPerSecond * 1000).round();
    final computed = Duration(
      milliseconds: max(ms, _minTravelDuration.inMilliseconds),
    );
    if (computed < minimum) return minimum;
    return computed;
  }

  Offset _randomPoint() {
    final minX = widget.padding.left + widget.size / 2;
    final minY = widget.padding.top + widget.size / 2;
    final maxX =
        widget.meadowSize.width - widget.padding.right - widget.size / 2;
    final maxY =
        widget.meadowSize.height - widget.padding.bottom - widget.size / 2;
    final dx = minX + _random.nextDouble() * max(0, maxX - minX);
    final dy = minY + _random.nextDouble() * max(0, maxY - minY);
    return Offset(dx, dy);
  }

  Offset _randomEntryPoint() {
    final minX = widget.padding.left - widget.size;
    final minY = widget.padding.top - widget.size;
    final maxX = widget.meadowSize.width - widget.padding.right + widget.size;
    final maxY = widget.meadowSize.height - widget.padding.bottom + widget.size;
    final side = _random.nextInt(4);
    switch (side) {
      case 0:
        return Offset(minX, minY + _random.nextDouble() * (maxY - minY));
      case 1:
        return Offset(maxX, minY + _random.nextDouble() * (maxY - minY));
      case 2:
        return Offset(minX + _random.nextDouble() * (maxX - minX), minY);
      default:
        return Offset(minX + _random.nextDouble() * (maxX - minX), maxY);
    }
  }

  Offset _randomNearbyPoint() {
    final minX = widget.padding.left + widget.size / 2;
    final minY = widget.padding.top + widget.size / 2;
    final maxX =
        widget.meadowSize.width - widget.padding.right - widget.size / 2;
    final maxY =
        widget.meadowSize.height - widget.padding.bottom - widget.size / 2;

    final radius = 110 + _random.nextDouble() * 90;
    final angle = _random.nextDouble() * pi * 2;
    final dx = _currentPosition.dx + cos(angle) * radius;
    final dy = _currentPosition.dy + sin(angle) * radius;

    var candidate = Offset(
      dx.clamp(minX, maxX).toDouble(),
      dy.clamp(minY, maxY).toDouble(),
    );

    final fromHome = candidate - _homePosition;
    final dist = fromHome.distance;
    if (dist > _maxRoamRadiusFromHome) {
      final scaled = fromHome * (_maxRoamRadiusFromHome / max(1.0, dist));
      candidate = _homePosition + scaled;
    }

    return Offset(
      candidate.dx.clamp(minX, maxX).toDouble(),
      candidate.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Offset _clampToBounds(Offset point, {double extra = 0}) {
    final minX = widget.padding.left + widget.size / 2 - extra;
    final minY = widget.padding.top + widget.size / 2 - extra;
    final maxX =
        widget.meadowSize.width -
        widget.padding.right -
        widget.size / 2 +
        extra;
    final maxY =
        widget.meadowSize.height -
        widget.padding.bottom -
        widget.size / 2 +
        extra;
    return Offset(
      point.dx.clamp(minX, maxX).toDouble(),
      point.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Offset _cubicBezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;
    return Offset(
      uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx,
      uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy,
    );
  }

  Duration _durationForDistance(Offset start, Offset end, {Duration? minimum}) {
    final distance = (end - start).distance;
    final ms = (distance / _pixelsPerSecond * 1000).round();
    final computed = Duration(
      milliseconds: max(ms, _minTravelDuration.inMilliseconds),
    );
    if (minimum == null) return computed;
    if (computed < minimum) return minimum;
    return computed;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentPosition.dx - widget.size / 2,
      top: _currentPosition.dy - widget.size / 2,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _fadeController,
          curve: Curves.easeOut,
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PronounButterflyAvatar(
                pronouns: widget.user.pronounSlots,
                size: widget.size,
                isFlapping: true,
                flapSpeed: const Duration(milliseconds: 980),
                centerGap: widget.user.pronounSlots.length >= 5 ? 12 : -8,
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
