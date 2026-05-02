import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/providers/currency_provider.dart';
import '../providers/setup_provider.dart';
import '../../../../core/models/user_setup_model.dart' as models;
import '../providers/setup_state.dart';
import 'package:expensia/features/profile/presentation/widgets/language_sheet.dart';

import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  late final PageController _pageController;

  late final TextEditingController _nameController;
  late final TextEditingController _cashController;
  late final TextEditingController _salaryController;
  late final TextEditingController _currencySearchController;
  bool _isSearchingCurrency = false;

  @override
  void initState() {
    super.initState();
    final setupState = ref.read(setupProvider);

    _pageController = PageController(initialPage: setupState.currentPage);
    _nameController = TextEditingController(text: setupState.name);
    _cashController = TextEditingController(
      text: setupState.cash > 0 ? setupState.cash.toString() : '',
    );
    _salaryController = TextEditingController(
      text: setupState.salary > 0 ? setupState.salary.toString() : '',
    );
    _currencySearchController = TextEditingController();
    _currencySearchController.addListener(() => setState(() {}));
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupProvider);
    final notifier = ref.read(setupProvider.notifier);
    final currenciesAsync = ref.watch(currencyCatalogProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withValues(alpha: 0.05),
              Theme.of(context).scaffoldBackgroundColor,
              cs.secondary.withValues(alpha: 0.03),
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
                        if (state.currentPage > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          context.pop();
                        }
                      },
                      icon: Icon(Icons.arrow_back_ios, color: cs.primary),
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
                                    index <= state.currentPage
                                        ? cs.primary
                                        : cs.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showLanguageSheet(context),
                      icon: Icon(Icons.language_rounded, color: cs.primary),
                    ),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => notifier.setPage(index),
                  children: [
                    _buildCurrencyPage(state, currenciesAsync),
                    _buildPersonalInfoPage(state),
                    _buildSalaryPage(state),
                  ],
                ),
              ),

              // Bottom Navigation
              Container(
                padding: EdgeInsets.all(24.w),
                child: Row(
                  children: [
                    // Only show Skip on Step 2 (Salary Information)
                    if (state.currentPage == 2)
                      Expanded(
                        child: TextButton(
                          onPressed: () => _completeSetup(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            'common.skip'.tr(),
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (state.currentPage == 2) SizedBox(width: 16.w),

                    // Always show Next/Complete button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            state.isLoading
                                ? null
                                : () {
                                  if (state.currentPage == 0) {
                                    if (state.selectedCurrency == null) {
                                      _showErrorSnackBar(
                                        'setup.error_currency'.tr(),
                                      );
                                      return;
                                    }
                                  } else if (state.currentPage == 1) {
                                    notifier.updatePersonalInfo(
                                      _nameController.text,
                                      double.tryParse(_cashController.text) ??
                                          0.0,
                                    );
                                  }

                                  if (state.currentPage < 2) {
                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  } else {
                                    _completeSetup();
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 8,
                          shadowColor: cs.primary.withValues(alpha: 0.4),
                        ),
                        child:
                            state.isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  state.currentPage == 2
                                      ? 'common.complete'.tr()
                                      : 'common.next'.tr(),
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

  Widget _buildPersonalInfoPage(SetupState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
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
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
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
                shaderCallback:
                    (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF6A11CB),
                        Color(0xFF2575FC),
                        Color(0xFFE91E63),
                      ],
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
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
                      prefixIcon: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              state.selectedCurrency?.currencySymbol ?? r'$',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(minWidth: 40.w, minHeight: 0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyPage(
    SetupState state,
    AsyncValue<List<models.CurrencyModel>> currenciesAsync,
  ) {
    final locale = context.locale.languageCode;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Stack(
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.w,
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
                      borderRadius: BorderRadius.circular(16.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 45.w,
                          height: 45.w,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 24.w,
                            color: Colors.amber[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchingCurrency = !_isSearchingCurrency;
                    if (!_isSearchingCurrency) _currencySearchController.clear();
                  });
                },
                icon: Icon(
                  _isSearchingCurrency
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _isSearchingCurrency
                ? FadeInLeft(
                  duration: const Duration(milliseconds: 300),
                  child: TextField(
                    controller: _currencySearchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'setup.search_currency'.tr(),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                    ),
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      child: ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                        child: Text(
                          'setup.currency_title'.tr(),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        'setup.currency_desc'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
          SizedBox(height: 24.h),
          Expanded(
            child: currenciesAsync.when(
              data: (currencies) {
                final query = _currencySearchController.text.toLowerCase();
                final filtered = currencies.where((c) {
                  final nameEn = c.currencyNameEn.toLowerCase();
                  final nameAr = c.currencyNameAr.toLowerCase();
                  final code = c.currencyCode.toLowerCase();
                  return nameEn.contains(query) ||
                      nameAr.contains(query) ||
                      code.contains(query);
                }).toList();

                return FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final currency = filtered[index];
                      final isSelected =
                          state.selectedCurrency?.id == currency.id;
                      final displayName =
                          locale == 'ar'
                              ? currency.currencyNameAr
                              : currency.currencyNameEn;

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
                                    : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            ref
                                .read(setupProvider.notifier)
                                .updateCurrency(currency);
                            if (_isSearchingCurrency) {
                              setState(() {
                                _isSearchingCurrency = false;
                                _currencySearchController.clear();
                              });
                            }
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
                                      : Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check
                                  : Icons.currency_exchange,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                              size: 20.w,
                            ),
                          ),
                          title: Text(
                            '${currency.flag} $displayName',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                            ),
                          ),
                          subtitle: Text(
                            '${currency.currencyCode} • ${currency.currencySymbol}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => Center(
                    child: Text(
                      'setup.currency_load_error'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryPage(SetupState state) {
    final notifier = ref.read(setupProvider.notifier);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
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
                shaderCallback:
                    (bounds) => const LinearGradient(
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
                  value: state.hasSalary,
                  onChanged: (value) {
                    notifier.updateSalaryInfo(hasSalary: value);
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

            if (state.hasSalary) ...[
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
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
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                state.selectedCurrency?.currencySymbol ?? r'$',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 40.w, minHeight: 0),
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
                      'setup.salary_day'.tr(),
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
                          value: state.salaryDay,
                          isExpanded: true,
                          hint: Text('setup.select_salary_day'.tr()),
                          items:
                              List.generate(31, (index) => index + 1)
                                  .map(
                                    (day) => DropdownMenuItem(
                                      value: day,
                                      child: Text(_formatSalaryDayOption(day)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            notifier.updateSalaryInfo(salaryDay: value);
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
                    value: state.autoAddSalary,
                    onChanged: (value) {
                      notifier.updateSalaryInfo(autoAddSalary: value);
                    },
                    title: Text(
                      'setup.auto_add'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'setup.auto_add_desc'.tr(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ],
        ),
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

  String _formatSalaryDayOption(int day) {
    if (context.locale.languageCode == 'ar') {
      return '$day';
    }

    return '$day${_getDaySuffix(day)} day';
  }

  Future<void> _completeSetup() async {
    final notifier = ref.read(setupProvider.notifier);

    // Sync current values before completion
    notifier.updatePersonalInfo(
      _nameController.text,
      double.tryParse(_cashController.text) ?? 0.0,
    );

    final state = ref.read(setupProvider);
    if (state.hasSalary) {
      notifier.updateSalaryInfo(
        salary: double.tryParse(_salaryController.text) ?? 0.0,
      );
    }

    try {
      await notifier.completeSetup(
        cashWalletName: 'setup.cash_wallet_name'.tr(),
        salaryWalletName: 'setup.salary_account_name'.tr(),
        cashNote: 'setup.initial_balance_note'.tr(),
        salaryNote: 'setup.initial_salary_note'.tr(),
      );

      // Show success message
      if (mounted) {
        _showSuccessSnackBar('setup.complete_success'.tr());

        // Invalidate state to ensure dashboard fetches fresh data
        ref.invalidate(walletProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(dashboardMetricsProvider);
        // Also invalidate settings so the new currency and profile data are loaded immediately
        ref.invalidate(defaultCurrencyProvider);

        // Navigate to dashboard after short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.go('/dashboard');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('setup.complete_failed'.tr(args: ['$e']));
      }
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
    _currencySearchController.dispose();
    super.dispose();
  }
}
