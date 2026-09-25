import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/brand_theme.dart';
import 'config/supabase_config.dart';
import 'l10n/app_strings.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sticker_pack_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'utils/configure_web.dart';
import 'utils/invite_deep_link.dart';
import 'utils/profile_deep_link.dart';
import 'utils/sticker_pack_link.dart';
import 'widgets/murkot_boot_screen.dart';
import 'widgets/unlumen/murkot_theme_transition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebApp();
  captureInitialProfileDeepLink();
  captureInitialInviteDeepLink();
  captureInitialStickerPackLink();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  ).timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException(
      'Supabase init > 10s — проверь сеть / VPN до supabase.co',
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService();
  final settingsService = SettingsService(prefs);

  runApp(MurkotApp(
    prefs: prefs,
    authService: authService,
    settingsService: settingsService,
  ));

  unawaited(authService.initialize());
}

class MurkotApp extends StatefulWidget {
  const MurkotApp({
    super.key,
    required this.prefs,
    required this.authService,
    required this.settingsService,
  });

  final SharedPreferences prefs;
  final AuthService authService;
  final SettingsService settingsService;

  @override
  State<MurkotApp> createState() => _MurkotAppState();
}

class _MurkotAppState extends State<MurkotApp> {
  /// Keeps navigator / screens alive across theme rebuilds.
  final _navKey = GlobalKey<NavigatorState>();

  /// Preserves curtain AnimationController across MaterialApp rebuilds.
  final _curtainKey = GlobalKey();

  bool _stickerRouteOpen = false;

  /// Stable home instance — recreating `home:` on every settings notify
  /// was resetting the whole app (looked like a full page reload).
  late final Widget _home = _MurkotRootHome(
    authService: widget.authService,
    settingsService: widget.settingsService,
    prefs: widget.prefs,
  );

  @override
  void initState() {
    super.initState();
    pendingStickerPack.addListener(_scheduleStickerPack);
    widget.authService.addListener(_scheduleStickerPack);
    widget.settingsService.addListener(_scheduleStickerPack);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleStickerPack());
  }

  @override
  void dispose() {
    pendingStickerPack.removeListener(_scheduleStickerPack);
    widget.authService.removeListener(_scheduleStickerPack);
    widget.settingsService.removeListener(_scheduleStickerPack);
    super.dispose();
  }

  /// Opens `/s/<name>` on top of login, guest, or the main screen.
  /// Telegram shows the pack before the set is installed.
  void _scheduleStickerPack() {
    final name = pendingStickerPack.value;
    if (name == null || _stickerRouteOpen) return;
    if (!widget.authService.isReady) return;
    if (!widget.authService.isAuthenticated && !widget.settingsService.isGuest) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stickerRouteOpen) return;
      if (!widget.authService.isAuthenticated &&
          !widget.settingsService.isGuest) {
        return;
      }
      final current = consumePendingStickerPack();
      if (current == null) return;
      final nav = _navKey.currentState;
      if (nav == null) {
        pendingStickerPack.value = current;
        return;
      }
      _stickerRouteOpen = true;
      hideMurkotHtmlBoot();
      nav
          .push(
            MaterialPageRoute<void>(
              builder: (context) => StickerPackScreen(
                shortName: current,
                settingsService: widget.settingsService,
              ),
            ),
          )
          .whenComplete(() {
            _stickerRouteOpen = false;
            _scheduleStickerPack();
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final strings = AppStrings(
          widget.settingsService.language,
          widget.settingsService,
        );

        return AppStringsScope(
          strings: strings,
          child: MaterialApp(
            navigatorKey: _navKey,
            title: strings.appTitle,
            debugShowCheckedModeBanner: false,
            locale: widget.settingsService.locale,
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: widget.settingsService.themeMode,
            themeAnimationStyle: AnimationStyle.noAnimation,
            theme: buildMurkotTheme(
              Brightness.light,
              lightFlavor: MurkotLightFlavor.light,
            ),
            darkTheme: buildMurkotTheme(Brightness.dark),
            builder: (context, child) {
              return MurkotThemeCurtain(
                key: _curtainKey,
                settings: widget.settingsService,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      widget.settingsService.textScaleFactor,
                    ),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: _home,
          ),
        );
      },
    );
  }
}

/// Auth-driven root. Type/key stay stable so MaterialApp never remounts
/// the navigator when only the theme changes.
class _MurkotRootHome extends StatelessWidget {
  const _MurkotRootHome({
    required this.authService,
    required this.settingsService,
    required this.prefs,
  });

  final AuthService authService;
  final SettingsService settingsService;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([authService, settingsService]),
      builder: (context, _) {
        if (!authService.isReady) {
          return const Scaffold(body: MurkotBootScreen());
        }
        if (authService.isAuthenticated) {
          if (settingsService.isGuest) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (settingsService.isGuest) {
                settingsService.setGuest(false);
              }
            });
          }
          final user = authService.currentUser!;
          // Temporarily hidden — onboarding stays in project but not shown.
          // Re-enable by removing this guard.
          const kDisableOnboarding = true;
          if (!kDisableOnboarding && needsOnboarding(user, prefs)) {
            hideMurkotHtmlBoot();
            return OnboardingScreen(
              authService: authService,
              settingsService: settingsService,
              prefs: prefs,
            );
          }
          return MainScreen(
            authService: authService,
            settingsService: settingsService,
            prefs: prefs,
          );
        }
        hideMurkotHtmlBoot();
        if (settingsService.isGuest) {
          return MainScreen(
            authService: authService,
            settingsService: settingsService,
            prefs: prefs,
            isGuest: true,
          );
        }
        if (authService.needsEmailVerification) {
          return EmailVerificationScreen(authService: authService);
        }
        return AuthScreen(
          authService: authService,
          settingsService: settingsService,
        );
      },
    );
  }
}

typedef TujhMessengerApp = MurkotApp; // legacy alias
