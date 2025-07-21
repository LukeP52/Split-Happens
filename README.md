# Split Happens

A SwiftUI expense splitting app with CloudKit integration that helps groups manage and split expenses easily.

## Features

- **Group Management**: Create and manage expense groups with multiple participants
- **Expense Tracking**: Add expenses with categories, split types, and detailed information
- **Balance Calculation**: Automatic calculation of who owes what to whom
- **Settlement Suggestions**: Smart suggestions for settling debts between participants
- **CloudKit Sync**: Real-time synchronization across all devices using iCloud
- **Multiple Currencies**: Support for different currencies (USD, EUR, GBP, CAD, AUD, JPY)
- **Expense Categories**: Organized expense tracking with predefined categories
- **Split Types**: Equal, percentage, and custom split options

## Project Structure

```
Split Happens/
├── Models/
│   ├── Group.swift              # Group data model with CloudKit integration
│   ├── Expense.swift            # Expense data model with categories and split types
│   └── CloudKitModels.swift    # CloudKit extensions and error handling
├── Managers/
│   ├── CloudKitManager.swift   # CloudKit operations and data management
│   └── ExpenseCalculator.swift # Balance calculations and settlement logic
├── ViewModels/
│   ├── GroupViewModel.swift    # Group data management and operations
│   └── ExpenseViewModel.swift  # Expense data management and operations
├── Views/
│   ├── GroupListView.swift     # Main group list with search and creation
│   ├── GroupDetailView.swift   # Group details with tabs for expenses/balances
│   ├── AddExpenseView.swift    # Add/edit expense form
│   └── BalancesView.swift      # Balance display and settlement suggestions
└── ContentView.swift           # Main app interface with iCloud sign-in
```

## CloudKit Configuration

The app uses CloudKit with the container identifier `iCloud.SplitHappens` and includes these record types:

### Group Record
- `name`: String - Group name
- `participants`: [String] - Array of participant names
- `participantIDs`: [String] - Array of participant IDs
- `totalSpent`: Double - Total amount spent in the group
- `lastActivity`: Date - Last activity timestamp
- `isActive`: Bool - Whether the group is active
- `currency`: String - Currency code (USD, EUR, etc.)

### Expense Record
- `groupReference`: String - Reference to the group ID
- `description`: String - Expense description
- `totalAmount`: Double - Total expense amount
- `paidBy`: String - Name of person who paid
- `paidByID`: String - ID of person who paid
- `splitType`: String - Split type (Equal, Percentage, Custom)
- `date`: Date - Expense date
- `category`: String - Expense category
- `participantNames`: [String] - Array of participant names for this expense

## Key Features

### 1. Group Management
- Create new groups with custom names and participants
- Add/remove participants from existing groups
- Set different currencies for each group
- View group activity and total spending

### 2. Expense Tracking
- Add expenses with detailed descriptions
- Categorize expenses (Food, Transportation, Entertainment, etc.)
- Choose split types: Equal, Percentage, or Custom
- Track who paid for each expense
- Set custom dates for expenses

### 3. Balance Calculations
- Automatic calculation of balances for each participant
- Shows who owes money and who is owed money
- Provides settlement suggestions to minimize transactions
- Real-time updates as expenses are added/modified

### 4. CloudKit Integration
- Real-time synchronization across devices
- Automatic conflict resolution
- Offline support with sync when connection is restored
- Secure data storage in iCloud

### 5. User Interface
- Modern SwiftUI interface with native iOS design
- Tabbed interface for expenses, balances, and summaries
- Search functionality for groups and expenses
- Pull-to-refresh for data updates
- Error handling with user-friendly messages

## Setup Instructions

1. **iCloud Configuration**: Ensure the app has CloudKit capabilities enabled
2. **Container Setup**: The app uses the container `iCloud.SplitHappens`
3. **Entitlements**: CloudKit entitlements are already configured
4. **Build and Run**: The app will automatically handle CloudKit setup

## Usage

1. **Sign in to iCloud**: The app requires iCloud sign-in for CloudKit functionality
2. **Create Groups**: Add expense groups with participants
3. **Add Expenses**: Record expenses with details and split information
4. **View Balances**: Check who owes what to whom
5. **Settle Debts**: Use settlement suggestions to pay back debts

## Technical Details

- **Framework**: SwiftUI for modern iOS development
- **Data Storage**: CloudKit for cloud synchronization
- **Architecture**: MVVM pattern with clear separation of concerns
- **Concurrency**: Async/await for CloudKit operations
- **Error Handling**: Comprehensive error handling with user feedback

## Requirements

- iOS 15.0+
- Xcode 13.0+
- iCloud account for CloudKit functionality
- Internet connection for initial setup and synchronization

## Future Enhancements

- Push notifications for expense updates
- Receipt photo upload and storage
- Export functionality for expense reports
- Multiple currency support within groups
- Recurring expense tracking
- Advanced split algorithms (proportional to income, etc.) 