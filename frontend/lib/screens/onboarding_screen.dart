import 'package:flutter/material.dart';
import 'role_selection_screen.dart';
import '../widgets/adaptive_layout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Simple File Sharing',
      description:
          'HydraShare makes it easy to send files between devices without any external servers.',
      icon: Icons.auto_awesome_rounded,
    ),
    OnboardingItem(
      title: 'Lightning Fast',
      description:
          'Utilize your local network for the fastest possible transfer speeds.',
      icon: Icons.bolt_rounded,
    ),
    OnboardingItem(
      title: 'Private & Secure',
      description:
          'Your data never leaves your network. Direct device-to-device encryption included.',
      icon: Icons.security_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      showAppBar: false,
      padding: EdgeInsets.zero,
      centerContent: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate height minus footer
          final footerHeight = 140.0; // Estimated footer height
          final viewHeight = MediaQuery.of(context).size.height - footerHeight;

          return Column(
            children: [
              SizedBox(
                height: viewHeight > 0 ? viewHeight : 500,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_items[index], theme);
                  },
                ),
              ),
              _buildFooter(theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPage(OnboardingItem item, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 100, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 64),
          Text(
            item.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            item.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _items.length,
              (index) => _buildIndicator(index == _currentPage, theme),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _items.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const RoleSelectionScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: Text(
                _currentPage < _items.length - 1 ? 'Next' : 'Get Started',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}
