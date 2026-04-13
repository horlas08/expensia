import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../../core/services/database_service.dart';
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
                    // Only show Skip on Step 2 (Salary Information)
                    if (_currentPage == 2)
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _completeSetup();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            'common.skip'.tr(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage == 2) SizedBox(width: 16.w),
                    
                    // Always show Next/Complete button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage == 0) {
                            if (_nameController.text.trim().isEmpty) {
                              _showErrorSnackBar('setup.error_name'.tr());
                              return;
                            }
                          } else if (_currentPage == 1) {
                            if (_selectedCurrencyModel == null) {
                              _showErrorSnackBar('setup.error_currency'.tr());
                              return;
                            }
                          }

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
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 8,
                          shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        child: Text(
                          _currentPage == 2 ? 'common.complete'.tr() : 'common.next'.tr(),
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
            duration: const Duration(milliseconds: 800),
            child: Stack(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 70.w,
                      height: 70.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 36.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'setup.personal_title'.tr(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'setup.personal_desc'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 32.h),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'setup.name_label'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'setup.name_label'.tr(),
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
                  'setup.initial_cash'.tr(),
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
                    // prefixText: '${_selectedCurrencyModel?.currencySymbol ?? r'$'} ',
                    // prefixStyle: Theme.of(context).textTheme.titleMedium,
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
            duration: const Duration(milliseconds: 800),
            child: Stack(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 70.w,
                      height: 70.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 36.w,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'setup.currency_title'.tr(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'setup.currency_desc'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
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
            duration: const Duration(milliseconds: 800),
            child: Stack(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 70.w,
                      height: 70.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.work_outline_rounded,
                        size: 36.w,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'setup.salary_title'.tr(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'setup.salary_desc'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
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
                  'setup.has_salary'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'setup.auto_add'.tr(),
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
                    'setup.salary_amount'.tr(),
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
                      prefixText: '${_selectedCurrencyModel?.currencySymbol ?? r'$'} ',
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

      // Initialize database with initial categories and wallet
      await DatabaseService().initializeSetup(
        name: userSetup.name,
        defaultCurrencyId: userSetup.defaultCurrency,
        cashBalance: userSetup.cash,
        salaryAmount: userSetup.salary,
        salaryDay: userSetup.dayOfSalary,
        hasSalary: userSetup.isOptions,
        autoAddSalary: userSetup.autoAddSalary,
      );

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
