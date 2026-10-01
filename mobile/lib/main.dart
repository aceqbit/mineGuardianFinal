import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/session_bloc.dart';
import 'core/socket/socket_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(_ConfigError(message: '$e'));
    return;
  }

  final auth = AuthRepository();
  final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) => auth.idToken(forceRefresh: forceRefresh));
  final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) => auth.idToken(forceRefresh: forceRefresh));
  final session = SessionBloc(auth: auth, api: api);

  runApp(MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AuthRepository>.value(value: auth),
      RepositoryProvider<ApiClient>.value(value: api),
      RepositoryProvider<SocketService>.value(value: socket),
    ],
    child: BlocProvider<SessionBloc>.value(
      value: session,
      child: MineGuardianApp(session: session, socket: socket),
    ),
  ));
}

class _ConfigError extends StatelessWidget {
  const _ConfigError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Setup needed\n\n$message', textAlign: TextAlign.center),
            ),
          ),
        ),
      );
}
