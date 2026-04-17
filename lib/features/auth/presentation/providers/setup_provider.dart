import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../../core/models/user_setup_model.dart';
import 'setup_state.dart';

part 'setup_provider.g.dart';

@riverpod
class Setup extends _$Setup {
  @override
  SetupState build() => SetupState();

  void setPage(int page) => state = state.copyWith(currentPage: page);

  void updatePersonalInfo(String name, double cash) {
    state = state.copyWith(name: name, cash: cash);
  }

  void updateCurrency(CurrencyModel currency) {
    state = state.copyWith(selectedCurrency: currency);
  }

  void updateSalaryInfo({
    bool? hasSalary,
    double? salary,
    int? salaryDay,
    bool? autoAddSalary,
  }) {
    state = state.copyWith(
      hasSalary: hasSalary,
      salary: salary,
      salaryDay: salaryDay,
      autoAddSalary: autoAddSalary,
    );
  }

  Future<void> completeSetup() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final prefsService = await SharedPreferencesService.getInstance();

      // Create user setup model
      final userSetup = UserSetupModel(
        name: state.name.trim(),
        defaultCurrency: state.selectedCurrency!.id,
        cash: state.cash,
        salary: state.hasSalary ? state.salary : 0.0,
        dayOfSalary: state.salaryDay,
        autoAddSalary: state.autoAddSalary,
        startThisMonth: false,
        isOptions: state.hasSalary,
      );

      // Save user setup
      await prefsService.setUserSetup(userSetup.toMap());

      // Initialize database
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
      await prefsService.setDefaultCurrency(state.selectedCurrency!);

      // Mark first page as completed
      await prefsService.setFirstPageCompleted();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }
}
