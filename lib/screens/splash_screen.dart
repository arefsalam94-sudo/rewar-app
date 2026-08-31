import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/page_background.dart';
import 'language_selection_screen.dart';

/// The first screen shown when the app launches.
///
/// A branded splash: full-screen vertical gradient (light mint at the top,
/// deep green at the bottom), the app logo with a soft glow, and the app
/// name below it in Plus Jakarta Sans. After a short delay it advances to the Language
/// selection screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Top of the gradient is light, so status-bar icons should be dark.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PageBackground(
          imageAsset: 'assets/images/main screen back image.webp',
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_Logo(), const SizedBox(height: 28), _Title()],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app logo with a soft glow behind it, matching the mockup.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 34,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          // Graceful placeholder until the real logo.png is dropped in.
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white.withValues(alpha: 0.25),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_outlined,
                size: 48,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The app name, two centered lines, in Plus Jakarta Sans with a soft shadow.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Kurdistan Paradise\nTravel Guide',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        color: AppColors.splashText,
        fontSize: 34,
        height: 1.15,
        letterSpacing: 0.5,
        shadows: [
          Shadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 6),
        ],
      ),
    );
  }
}
