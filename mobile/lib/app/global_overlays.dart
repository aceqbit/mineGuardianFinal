import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../contracts/enums.dart';
import '../contracts/routes.dart';
import '../core/api/api_client.dart';
import '../core/auth/session_bloc.dart';
import '../core/socket/socket_service.dart';
import '../features/crisis/bloc/crisis_bloc.dart';
import '../features/crisis/data/crisis_repository.dart';
import 'siren.dart';
import 'theme/motion.dart';
import 'theme/tokens.dart';

/// Wraps every page via a ShellRoute: crisis flash, siren, banners and navigation per role (CLAUDE.md §13).
/// admin: 3 red pulses + siren + open the crisis console. supervisor: banner + 3 s siren. miner: EVACUATE banner + vibration + evacuation view.
class GlobalOverlays extends StatefulWidget {
  const GlobalOverlays({super.key, required this.child, this.crisisBloc, this.siren});
  final Widget child;

  /// Tests inject these; the app builds its own.
  final CrisisBloc? crisisBloc;
  final SirenController? siren;

  @override
  State<GlobalOverlays> createState() => _GlobalOverlaysState();
}

class _GlobalOverlaysState extends State<GlobalOverlays> with SingleTickerProviderStateMixin {
  CrisisBloc? _bloc;
  SirenController? _siren;
  bool _ownsBloc = false, _ownsSiren = false;
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Timer? _clearTimer;

  Role? get _role {
    final s = context.read<SessionBloc>().state;
    return s is SessionAuthenticated ? s.user.role : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bloc == null) {
      _ownsBloc = widget.crisisBloc == null;
      _bloc = widget.crisisBloc ??
          CrisisBloc(repo: CrisisRepository(api: context.read<ApiClient>()), socket: context.read<SocketService>(), isStaff: () => _role == Role.admin || _role == Role.supervisor);
    }
    if (_siren == null) {
      _ownsSiren = widget.siren == null;
      _siren = widget.siren ?? SirenController();
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _flash.dispose();
    if (_ownsBloc) _bloc?.close();
    if (_ownsSiren) _siren?.dispose();
    super.dispose();
  }

  String get _path => GoRouter.of(context).routeInformationProvider.value.uri.path;

  void _go(String route) {
    if (_path != route.split('?').first) GoRouter.of(context).go(route);
  }

  Future<void> _onActivated() async {
    final role = _role;
    if (role == null) return;
    switch (role) {
      case Role.admin:
        if (!Motion.reduce(context)) {
          for (var i = 0; i < 3 && mounted; i++) {
            await _flash.forward(from: 0);
            await _flash.reverse();
          }
        }
        unawaited(_siren!.start(forAtMost: const Duration(seconds: 10)));
        _go(Routes.adminCrisis);
      case Role.supervisor:
        unawaited(_siren!.start(forAtMost: const Duration(seconds: 3)));
      case Role.miner:
        unawaited(HapticFeedback.vibrate());
        _go('${Routes.workerSos}?mode=evac');
    }
  }

  void _onResolved() {
    unawaited(_siren!.stop());
    _clearTimer?.cancel();
    if (_role != Role.admin) {
      _clearTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) _bloc!.add(const CrisisCleared());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _bloc!;
    final session = context.watch<SessionBloc>().state;
    return BlocProvider<CrisisBloc>.value(
      value: bloc,
      child: BlocListener<SessionBloc, SessionState>(
        listener: (context, s) {
          if (s is SessionAuthenticated) {
            bloc.add(const CrisisStarted());
          } else {
            bloc.add(const CrisisCleared());
            unawaited(_siren!.stop());
          }
        },
        child: MultiBlocListener(
          listeners: [
            BlocListener<CrisisBloc, CrisisState>(listenWhen: (a, b) => a.activationSeq != b.activationSeq, listener: (context, s) => _onActivated()),
            BlocListener<CrisisBloc, CrisisState>(listenWhen: (a, b) => a.phase != CrisisPhase.resolved && b.phase == CrisisPhase.resolved, listener: (context, s) => _onResolved()),
          ],
          child: Stack(children: [
            Positioned.fill(child: widget.child),
            if (session is SessionAuthenticated) ...[
              Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: _CrisisBanner(role: session.user.role, onGo: _go))),
              Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _flash, builder: (_, _) => ColoredBox(color: MgColors.of(context).crisis.withValues(alpha: 0.45 * _flash.value))))),
              Positioned(right: Space.md, bottom: Space.x4 + Space.lg, child: _SirenChip(siren: _siren!)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CrisisBanner extends StatelessWidget {
  const _CrisisBanner({required this.role, required this.onGo});
  final Role role;
  final void Function(String) onGo;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CrisisBloc, CrisisState>(
      builder: (context, s) {
        if (s.phase == CrisisPhase.idle) return const SizedBox.shrink();
        final c = MgColors.of(context);
        final resolved = s.phase == CrisisPhase.resolved;
        final (text, route) = switch (role) {
          Role.miner => (resolved ? (s.falseAlarm ? 'False alarm. You can continue your shift.' : 'Emergency resolved. Follow your supervisor.') : 'EVACUATE — follow the route on your screen', '${Routes.workerSos}?mode=evac'),
          Role.supervisor => (resolved ? 'Crisis resolved' : 'CRISIS ACTIVE — open the crisis view', Routes.crisisView),
          Role.admin => (resolved ? 'Crisis resolved — open the report' : 'CRISIS ACTIVE — open the console', Routes.adminCrisis),
        };
        return Semantics(
          liveRegion: true,
          button: true,
          label: text,
          child: Material(
            color: resolved ? c.success : c.crisis,
            child: InkWell(
              onTap: () => onGo(route),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                child: Row(children: [
                  Icon(resolved ? Icons.check_circle : Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SirenChip extends StatelessWidget {
  const _SirenChip({required this.siren});
  final SirenController siren;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: siren,
      builder: (context, _) {
        if (!siren.blocked && !siren.playing && !siren.muted) return const SizedBox.shrink();
        final label = siren.blocked ? 'Tap to enable siren' : (siren.muted ? 'Siren muted' : 'Mute siren');
        final icon = siren.blocked ? Icons.volume_up : (siren.muted ? Icons.volume_off : Icons.volume_off_outlined);
        return Material(
          color: MgColors.of(context).ink800,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.pill),
            onTap: () => siren.blocked ? siren.enable() : siren.toggleMute(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: Space.sm), Text(label, style: const TextStyle(color: Colors.white))]),
            ),
          ),
        );
      },
    );
  }
}
