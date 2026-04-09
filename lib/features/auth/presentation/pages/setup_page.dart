import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../../core/models/user_setup_model.dart' as models;

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cashController = TextEditingController(
    text: '0',
  );
  final TextEditingController _salaryController = TextEditingController();

  models.CurrencyModel? _selectedCurrencyModel;
  bool _hasSalary = false;
  int? _salaryDay;
  bool _autoAddSalary = false;

  List<models.CurrencyModel> get _currencies => [
    models.CurrencyModel(
      id: 1,
      currencyNameAr: 'دولار أمريكي',
      currencyNameEn: 'US Dollar',
      countryCode: 'US',
      currencyCode: 'USD',
      currencySymbol: '\$',
      rateToUsd: 1.0,
      flag: '🇺🇸',
    ),
    models.CurrencyModel(
      id: 2,
      currencyNameAr: 'يورو',
      currencyNameEn: 'Euro',
      countryCode: 'EU',
      currencyCode: 'EUR',
      currencySymbol: '€',
      rateToUsd: 0.85,
      flag: '🇪🇺',
    ),
    models.CurrencyModel(
      id: 3,
      currencyNameAr: 'جنيه إسترليني',
      currencyNameEn: 'British Pound',
      countryCode: 'GB',
      currencyCode: 'GBP',
      currencySymbol: '£',
      rateToUsd: 0.73,
      flag: '🇬🇧',
    ),
    models.CurrencyModel(
      id: 4,
      currencyNameAr: 'ين ياباني',
      currencyNameEn: 'Japanese Yen',
      countryCode: 'JP',
      currencyCode: 'JPY',
      currencySymbol: '¥',
      rateToUsd: 110.0,
      flag: '🇯🇵',
    ),
    models.CurrencyModel(
      id: 5,
      currencyNameAr: 'ريال سعودي',
      currencyNameEn: 'Saudi Riyal',
      countryCode: 'SA',
      currencyCode: 'SAR',
      currencySymbol: '﷼',
      rateToUsd: 3.75,
      flag: '🇸🇦',
    ),
    models.CurrencyModel(
      id: 6,
      currencyNameAr: 'درهم إماراتي',
      currencyNameEn: 'UAE Dirham',
      countryCode: 'AE',
      currencyCode: 'AED',
      currencySymbol: 'د.إ',
      rateToUsd: 3.67,
      flag: '🇦🇪',
    ),
    models.CurrencyModel(
      id: 7,
      currencyNameAr: 'جنيه مصري',
      currencyNameEn: 'Egyptian Pound',
      countryCode: 'EG',
      currencyCode: 'EGP',
      currencySymbol: 'ج.م',
      rateToUsd: 15.7,
      flag: '🇪🇬',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress Indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_currentPage > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          context.pop();
                        }
                      },
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: List.generate(
                          3,
                          (index) => Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.symmetric(horizontal: 2.w),
                              decoration: BoxDecoration(
                                color:
                                    index <= _currentPage
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48.w),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildPersonalInfoPage(),
                    _buildCurrencyPage(),
                    _buildSalaryPage(),
                  ],
                ),
              ),

              // Bottom Navigation
              Container(
                padding: EdgeInsets.all(24.w),
                child: Row(
                  children: [
                    if (_currentPage < 2)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) SizedBox(width: 16.w),
                    if (_currentPage > 0)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage < 2) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeSetup();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 8,
                            shadowColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.4),
                          ),
                          child: Text(
                            _currentPage == 2 ? 'Complete Setup' : 'Next',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

  Widget _buildPersonalInfoPage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 48.w,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            child: Text(
              'Let\'s Get Personal',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'Tell us a bit about yourself to personalize your experience.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 32.h),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Name',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Initial Cash',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    prefixText: '\$ ',
                    prefixStyle: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 48.w,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            child: Text(
              'Choose Your Currency',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'Select your preferred currency for all transactions.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: ListView.builder(
                itemCount: _currencies.length,
                itemBuilder: (context, index) {
                  final currency = _currencies[index];
                  final isSelected = _selectedCurrencyModel?.id == currency.id;

                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCurrencyModel = currency;
                        });
                      },
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 4.h,
                      ),
                      leading: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.currency_exchange,
                          color:
                              isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                          size: 20.w,
                        ),
                      ),
                      title: Text(
                        '${currency.flag} ${currency.displayName}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                      ),
                      subtitle: Text(
                        '${currency.currencyCode} • ${currency.currencySymbol}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryPage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_outline_rounded,
                size: 48.w,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            child: Text(
              'Salary Information',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'Help us track your income automatically (optional).',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 32.h),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: SwitchListTile(
                value: _hasSalary,
                onChanged: (value) {
                  setState(() {
                    _hasSalary = value;
                  });
                },
                title: Text(
                  'I have a regular salary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Enable automatic salary tracking',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          if (_hasSalary) ...[
            SizedBox(height: 24.h),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Salary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      prefixText: '\$ ',
                      prefixStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),
            FadeInUp(
              delay: const Duration(milliseconds: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salary Day',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _salaryDay,
                        isExpanded: true,
                        hint: Text('Select day of month'),
                        items:
                            List.generate(31, (index) => index + 1)
                                .map(
                                  (day) => DropdownMenuItem(
                                    value: day,
                                    child: Text(
                                      '$day${_getDaySuffix(day)} day',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _salaryDay = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),
            FadeInUp(
              delay: const Duration(milliseconds: 1000),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: SwitchListTile(
                  value: _autoAddSalary,
                  onChanged: (value) {
                    setState(() {
                      _autoAddSalary = value;
                    });
                  },
                  title: Text(
                    'Auto-add salary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically add salary on selected day',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<void> _completeSetup() async {
    try {
      final prefsService = await SharedPreferencesService.getInstance();

      // Validate required fields
      if (_nameController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter your name');
        return;
      }

      if (_selectedCurrencyModel == null) {
        _showErrorSnackBar('Please select a currency');
        return;
      }

      // Create user setup model
      final userSetup = models.UserSetupModel(
        name: _nameController.text.trim(),
        defaultCurrency: _selectedCurrencyModel!.id,
        cash: double.tryParse(_cashController.text) ?? 0.0,
        salary:
            _hasSalary ? (double.tryParse(_salaryController.text) ?? 0.0) : 0.0,
        dayOfSalary: _salaryDay ?? 1,
        autoAddSalary: _autoAddSalary,
        startThisMonth: false, // Default from old implementation
        isOptions: _hasSalary, // Match old logic
      );

      // Save user setup
      await prefsService.setUserSetup(userSetup.toMap());

      // Save user name separately
      await prefsService.setUserName(userSetup.name);

      // Save default currency
      await prefsService.setDefaultCurrency(_selectedCurrencyModel!);

      // Mark first page as completed
      await prefsService.setFirstPageCompleted();

      // Show success message
      _showSuccessSnackBar('Setup completed successfully!');

      // Navigate to dashboard
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go('/dashboard');
        }
      });
    } catch (e) {
      _showErrorSnackBar('Setup failed: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _cashController.dispose();
    _salaryController.dispose();
    super.dispose();
  }
}
