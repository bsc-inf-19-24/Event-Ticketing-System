# Event Ticketing System — Mobile Application

## About the Project

The Event Ticketing System Mobile Application is a Flutter-based application designed to allow customers to access tickets they have already purchased through the existing Event Ticketing Web Application.

The mobile application will allow customers to retrieve their purchased tickets, save them on their mobile devices, and access and display them offline when presenting them at an event.

The project aims to make event ticket access more convenient, even when an internet connection is unavailable.

## Project Objectives

- Allow customers to log in using their existing web application accounts.
- Retrieve tickets purchased through the web application.
- Display ticket details, including event name, date, venue, and ticket status where available.
- Allow customers to save purchased tickets for offline access.
- Display the ticket's QR code or other official entry credential.
- Provide access to customer profile information.
- Offer a simple and user-friendly mobile interface.

## Technology Stack

- **Flutter:** Mobile application development framework.
- **Dart:** Programming language.
- **Git and GitHub:** Version control and team collaboration.
- **Existing Web Application Backend/API:** Authentication and retrieval of customer and ticket data.

## Project Structure

The Flutter application is located inside the `mobile` directory.

```text
Event-Ticketing-System/
├── mobile/
│   ├── lib/
│   ├── test/
│   ├── android/
│   ├── pubspec.yaml
│   └── ...
└── README.md
```

The exact structure may evolve as development progresses.

## Prerequisites

Before running the application, ensure you have installed:

- Git
- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio or another compatible development environment
- An Android emulator or a supported physical device

Verify your Flutter installation by running:

```bash
flutter doctor
```

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/bsc-inf-19-24/Event-Ticketing-System.git
```

### 2. Navigate to the Flutter Project

```bash
cd Event-Ticketing-System/mobile
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Check the Development Environment

```bash
flutter doctor
```

Resolve any required setup issues reported by Flutter before running the application.

### 5. Run the Application

Start an Android emulator or connect a supported device, then run:

```bash
flutter devices
flutter run
```

## Planned Application Features

### Authentication
Customers will be able to log in using accounts associated with the existing web application, subject to backend support.

### Home Screen
Provides the main navigation area and convenient access to the customer's tickets and profile.

### Customer Profile
Displays available information about the authenticated customer.

### Ticket Management
Retrieves purchased tickets from the existing backend and displays ticket details and entry credentials.

### Offline Ticket Access
Allows customers to view previously downloaded tickets without an internet connection. Ticket validity and entry verification must follow the existing ticket verification system.

## Team Development and Collaboration

The project is developed collaboratively using GitHub Issues, branches, and pull requests.

Team members should:

1. Review their assigned GitHub issues before starting implementation.
2. Create a separate branch for each feature or task.
3. Implement and test their changes locally.
4. Commit changes with clear and descriptive messages.
5. Push their branches to GitHub and open pull requests.
6. Review changes and resolve conflicts before merging into the main branch.

### Current Feature Assignments

- Matthews :Customer profile section.
- Robert: Home section.
- Florence: Login and authentication section.
- Deborah: Ticket retrieval, download, and offline access.

Project setup, backend integration, and testing should be coordinated across the team.

## Important Notes

- The mobile application does not handle a new ticket purchase; customers purchase tickets through the existing web application.
- The existing backend is the source of truth for ticket ownership and validity.
- Previously downloaded tickets should remain accessible offline.
- API endpoints, authentication requirements, and ticket QR-code validation must be confirmed with the backend implementation.
- Never commit passwords, API secrets, access tokens, or personal local configuration files to GitHub.

## Project Status

**Status:** In Development

Features and documentation will be updated as the project progresses.

## Contribution

Team members are encouraged to contribute through assigned issues, feature branches, code reviews, and pull requests.

Please refer to the repository's GitHub Issues for current tasks, priorities, and implementation requirements.
