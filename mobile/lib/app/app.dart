import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_bloc.dart';
import '../core/socket/socket_service.dart';
import '../core/sync/sync_engine.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class MineGuardianApp extends StatefulWidget {
  const MineGuardianApp({super.key, required this.session, required this.socket, this.engine, this.extraRoutes = const []});
  final SessionBloc session;
  final SocketService socket;
  final SyncEngine? engine;
  final List<RouteBase> extraRoutes;

  @override
  State<MineGuardianApp> createState() => _MineGuardianAppState();
}

class _MineGuardianAppState extends State<MineGuardianApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(widget.session, extraRoutes: widget.extraRoutes);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.engine?.drain();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listener: (context, state) {
        if (state is SessionAuthenticated) {
          widget.socket.connect();
          widget.engine?.start();
        } else {
          widget.socket.disconnect();
          widget.engine?.stop();
        }
      },
      child: MaterialApp.router(
        title: 'Mine Guardian',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
