# Design Guidelines & System

## 1. Visual Aesthetics
- **Colors**: Use elegant, high-contrast combinations. 
  - *Light Mode*: Clean white backgrounds, subtle light-gray borders, vibrant primary accents (e.g., Electric Indigo, Mint Green).
  - *Dark Mode*: Deep charcoal/pitch-black surfaces (`#121212`, `#1E1E1E`), neon accents for text/icons, ensuring contrast readability.
- **Typography**: `GoogleFonts.googleSans` or `Poppins` for a modern, rounded, and friendly feel. Weight 700 for headings, 400/500 for bodies.

## 2. Animation Principles
- **Hero Transitions**: Images, profile pictures, and transaction cards should scale and move seamlessly between list and detail views.
- **OpenContainer**: Use for tapping on list items (Transactions, Wallets) to expand into their full screen modal.
- **Staggered Entrances**: Lists (e.g., Transactions) should fade and slide up (`animate_do`'s `FadeInUp`) in a staggered interval upon loading.
- **Micro-interactions**: 
  - Buttons must squish slightly when tapped (Scale transition).
  - Modals should slide elegantly from the bottom using `smooth_sheets`.
  - Empty states should feature looping soft animations (or `animated_emoji`).

## 3. Reusable Components
- **Custom Button**: A pill-shaped or rounded-rectangle button with soft drop-shadows and subtle gradient backgrounds.
- **Glassmorphic Cards**: Used on the Dashboard for balance summaries, combining a semi-transparent foreground with blur backdrop filters.
- **Form Fields**: Input fields should have animated floating labels, a clear focus border, and smooth suffix icon transitions.

## 4. State Management (Riverpod)
- Keep UI components "dumb". Let `ConsumerWidget` or `HookConsumerWidget` listen to state.
- Handle AsyncValue (`loading`, `data`, `error`) gracefully with animated skeleton loaders (shimmer) rather than plain `CircularProgressIndicator`s.

## 5. Clean Architecture Stucture
- **`core/`**: Foundations (Router, Theme, Localization, Shared Widgets).
- **`features/`**: Domain specific logic, with internal `presentation/`, `providers/`, and `data/` layers where complex logic demands.
