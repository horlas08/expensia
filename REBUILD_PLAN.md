# Expensia Rebuild Roadmap: From Legacy to Modern Excellence

This document outlines the strategic plan for reconstructing the Expensia mobile application using modern architecture, high-fidelity UI, and robust state management.

## Vision
Transform the existing "Expensia" codebase into a premium, professional-grade financial management tool that combines the stability of the legacy core with state-of-the-art Flutter development practices.

---

## Phase 1: Setup & Data Foundation (Status: 90%)
Establish the environment and initial data acquisition.
- [x] **Project Scaffolding**: Setup Riverpod, GoRouter, and ScreenUtil.
- [x] **Database Port**: Migrate legacy SQL creation scripts to `DatabaseService`.
- [x] **Premium Onboarding**: Implement high-fidelity `SetupPage` with glassmorphic design.
- [ ] **Initial State Management**: Complete the transition of user setup data from UI to Providers.

## Phase 2: The Core Ledger (Status: Incoming)
Rebuild the primary financial engine.
- **Wallet Intelligence**: Port `wallets` features. Support for multi-currency balances.
- **Transaction Engine**: Port `transactions` features. Implement a refined "Quick Add" experience.
- **Smart Categorization**: Port and modernize the `categories` management system with custom icon support.

## Phase 3: Analytics & Financial Insights
Provide users with actionable data visualization.
- **Modern Reports**: Port legacy reporting logic into highly animated charts (using `fl_chart` or similar).
- **Financial Calculator**: Rebuild the in-app calculator with a modern, integrated feel.
- **Budgeting Engine**: Implement monthly budget tracking and overspending alerts.

## Phase 4: Advanced Financial Tools
Port specialized features from the legacy app.
- **Debt & Credit Tracking**: Port the `debt` module with specific logic for payment reminders.
- **Installment Planner**: Port the `installment` tracking logic including recurring payment schedules.
- **Intelligent Reminders**: Rebuild `scedule_notifications` using modern local notification patterns.

## Phase 5: Polish & Ecosystem
Final refinements and user-facing documentation.
- **Theme Engine**: Robust Support for Dark/Light modes with specialized glassmorphic themes.
- **Data Export**: Implement CSV/PDF export features for financial transparency.
- **Security Layer**: Biometric unlock and safe data encryption.

---

## Technical Migration Guidelines
1. **Model First**: Always create clear, immputable data models (using `freezed` if possible) before porting UI logic.
2. **Provider Driven**: Business logic must reside in Riverpod `Notifiers`, never in UI `States`.
3. **Design Consistency**: Adhere to the glassmorphic design system established in the `SetupPage`.
4. **Data Parity**: Verify every database change against `old/lib/core/data_base/` to ensure zero data loss during migrations.
