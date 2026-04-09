# AI Context: Expensia Modernization Progress

This document serves as a status report and context anchor for AI agents working on the Expensia modernization project.

## Current Project State
We are in the process of rebuilding a legacy personal finance application with a premium, modern UI and a robust Clean Architecture / Riverpod backend.

### Technical Stack
- **State Management**: [Riverpod](https://riverpod.dev/) (Currently transitioning from legacy BLoC).
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router).
- **Persistence**: [SQLite](https://pub.dev/packages/sqflite) with a custom `DatabaseService` for legacy data parity.
- **UI/UX**: 
    - [Flutter ScreenUtil](https://pub.dev/packages/flutter_screenutil) for responsiveness.
    - [AnimateDo](https://pub.dev/packages/animate_do) for premium entrance animations.
    - CSS-like Glassmorphic design language (Blurred backgrounds, Gradients, Soft shadows).

### Completed Components
1. **Database Foundation**: `DatabaseService` handles schema creation and initial seeding of categories/currencies from legacy SQL scripts.
2. **Setup Experience**: `SetupPage` has been modernized with high-fidelity glassmorphic visuals and multi-step onboarding.
3. **Core Models**: `UserSetupModel`, `CurrencyModel` implemented for onboarding flow.

### Design Principles
- **Aesthetics**: Premium, vibrant colors, glassmorphism.
- **Layout**: Adaptive spacing using `.w`, `.h`, `.r` from ScreenUtil.
- **Interactions**: Haptic-ready feel with smooth transitions.

## Data Parity Requirements
The `old/` folder contains a legacy SQLite implementation. We MUST ensure that table names (`wallets`, `expenses`, `categories`, etc.) and initial seed data match the original app to maintain compatibility with legacy backups if needed.

## Active Files
- `lib/features/auth/presentation/pages/setup_page.dart`: Modernized onboarding.
- `lib/core/services/database_service.dart`: Core SQLite service.
- `lib/core/models/user_setup_model.dart`: Data structure for initial user state.
