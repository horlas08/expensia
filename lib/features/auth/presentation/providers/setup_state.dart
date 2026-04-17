import '../../../../core/models/user_setup_model.dart';

class SetupState {
  final String name;
  final double cash;
  final double salary;
  final CurrencyModel? selectedCurrency;
  final bool hasSalary;
  final int salaryDay;
  final bool autoAddSalary;
  final int currentPage;
  final bool isLoading;
  final String? errorMessage;

  SetupState({
    this.name = '',
    this.cash = 0.0,
    this.salary = 0.0,
    this.selectedCurrency,
    this.hasSalary = false,
    this.salaryDay = 1,
    this.autoAddSalary = false,
    this.currentPage = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  SetupState copyWith({
    String? name,
    double? cash,
    double? salary,
    CurrencyModel? selectedCurrency,
    bool? hasSalary,
    int? salaryDay,
    bool? autoAddSalary,
    int? currentPage,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SetupState(
      name: name ?? this.name,
      cash: cash ?? this.cash,
      salary: salary ?? this.salary,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      hasSalary: hasSalary ?? this.hasSalary,
      salaryDay: salaryDay ?? this.salaryDay,
      autoAddSalary: autoAddSalary ?? this.autoAddSalary,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
