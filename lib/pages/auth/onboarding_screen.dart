import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF17324D)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  const TourAnchor(
                    name: 'Welcome to Emerge Kentucky Alumni',
                    child: Text(
                      'Welcome to Emerge Kentucky Alumni',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TourAnchor(
                    name:
                        'Connect, share, and grow with a supportive community.',
                    child: Text(
                      'Connect, share, and grow with a supportive community.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TourAnchor(
                    name: 'Sign In',
                    child: ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TourAnchor(
                    name: 'Create Account',
                    child: OutlinedButton(
                      onPressed: () => context.go('/signup'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
