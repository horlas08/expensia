import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../profile/presentation/widgets/language_sheet.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'onboarding.step1.title',
      'subtitle': 'onboarding.step1.subtitle',
      'image': 'assets/images/onboarding_expenses.png'
    },
    {
      'title': 'onboarding.step2.title',
      'subtitle': 'onboarding.step2.subtitle',
      'image': 'assets/images/onboarding_debts.png'
    },
    {
      'title': 'onboarding.step3.title',
      'subtitle': 'onboarding.step3.subtitle',
      'image': 'assets/images/onboarding_installments.png'
    },
    {
      'title': 'onboarding.step4.title',
      'subtitle': 'onboarding.step4.subtitle',
      'image': 'assets/images/onboarding_reports.png'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return FadeIn(
                duration: const Duration(milliseconds: 800),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        _onboardingData[index]['image']!,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 48),
                      FadeInUp(
                        child: Text(
                          _onboardingData[index]['title']!.tr(),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          _onboardingData[index]['subtitle']!.tr(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              onPressed: () => showLanguageSheet(context),
              icon: Icon(
                Icons.language_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _onboardingData.length,
                    (index) => buildDot(index, context),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_currentIndex == _onboardingData.length - 1) {
                      context.go('/first');
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 50,
                    width: _currentIndex == _onboardingData.length - 1 ? 140 : 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    alignment: Alignment.center,
                    child: _currentIndex == _onboardingData.length - 1
                        ? Text(
                            "get_started.title".tr(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: _currentIndex == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentIndex == index
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
