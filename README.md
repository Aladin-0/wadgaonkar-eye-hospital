# wadgaonkar_eye_hospital

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Monorepo Architecture

- **`apps/patient_app/`**: Patient-facing Flutter app. Patients can browse doctors, book appointments, and view QR passes.
- **`apps/admin_app/`**: Staff-facing Flutter app. Hospital staff can view today's schedule and check-in patients via QR code scanner or manual entry.
- **`packages/weh_shared/`**: Shared models, constants, themes, and API utilities used by both apps.
- **`backend/`**: Django REST Framework + Celery + PostgreSQL backend.

## Quick Start (Local Desktop Development)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
