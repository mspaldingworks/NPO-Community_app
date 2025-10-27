import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/animations/trans_connect_open_video.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _isInitialized = true);
        _controller
          ..setVolume(1.0)
          ..play();
        _controller.addListener(_handleVideoProgress);
      }).catchError((_) {
        _navigateNext();
      });
  }

  void _handleVideoProgress() {
    if (_hasNavigated) return;
    final value = _controller.value;
    if (value.isInitialized && !value.isPlaying && value.position >= value.duration) {
      _navigateNext();
    }
  }

  void _navigateNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    context.go('/onboarding');
  }

  @override
  void dispose() {
    _controller.removeListener(_handleVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _navigateNext,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
