// ModernAddExpenseView.swift
import SwiftUI

struct ModernAddExpenseView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var description = ""
    @State private var totalAmount = ""
    @State private var selectedPaidBy = ""
    @State private var selectedCategory = ExpenseCategory.other
    @State private var selectedParticipants: Set<String> = []
    @State private var selectedSplitType: SplitType = .equal
    @State private var participantPercentages: [String: Double] = [:]
    @State private var participantCustomAmounts: [String: String] = [:]
    @State private var isCreating = false
    @State private var showingAmountPad = false
    
    private var isFormValid: Bool {
        guard !description.isEmpty,
              !totalAmount.isEmpty,
              let totalExpense = Double(totalAmount),
              totalExpense > 0,
              !selectedPaidBy.isEmpty,
              !selectedParticipants.isEmpty else {
            return false
        }
        
        // Validate split totals
        switch selectedSplitType {
        case .equal:
            return true // Even splits are always valid
        case .percentage:
            let totalPercentage = participantPercentages.values.reduce(0, +)
            return abs(totalPercentage - 100.0) < 0.01 // Allow for small floating point differences
        case .custom:
            let totalCustomAmount = participantCustomAmounts.compactMapValues { Double($0) }.values.reduce(0, +)
            return abs(totalCustomAmount - totalExpense) < 0.01 // Allow for small floating point differences
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom navigation bar
                    customNavBar
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 1. Description section
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Description", systemImage: "text.alignleft")
                                    .font(AppFonts.captionMedium)
                                    .foregroundColor(AppColors.secondaryText)
                                
                                TextField("What was this expense for?", text: $description)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.primaryText)
                                    .padding(16)
                                    .background(AppColors.tertiaryBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.borderColor, lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 20)
                            
                            // 2. Amount display
                            VStack(spacing: 12) {
                                Text("Tap to enter amount")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                
                                Button(action: { showingAmountPad = true }) {
                                    Text(totalAmount.isEmpty ? "$0.00" : formatCurrency(Double(totalAmount) ?? 0))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 32)
                                        .background(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .fill(AppColors.accent.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                        .stroke(AppColors.accent.opacity(0.3), lineWidth: 2)
                                                )
                                        )
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.vertical, 20)
                            
                            // Who paid selector
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Who paid?", systemImage: "person.fill")
                                    .font(AppFonts.captionMedium)
                                    .foregroundColor(AppColors.secondaryText)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 12) {
                                    ForEach(group.participants, id: \.self) { participant in
                                        PayerChip(
                                            name: participant,
                                            isSelected: selectedPaidBy == participant,
                                            action: { selectedPaidBy = participant }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // 3. Split configuration with tabs
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Split between", systemImage: "person.2.fill")
                                    .font(AppFonts.captionMedium)
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(.horizontal, 20)
                                
                                // Split type tabs
                                splitTypeSelector
                                    .padding(.horizontal, 20)
                                
                                // Split content based on selected type
                                splitContent
                                    .padding(.horizontal, 20)
                            }
                            
                            // 4. Category selector (moved to bottom)
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Category", systemImage: "square.grid.2x2")
                                    .font(AppFonts.captionMedium)
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                                            CategoryChip(
                                                category: category,
                                                isSelected: selectedCategory == category,
                                                action: { selectedCategory = category }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                        .padding(.top, 20)
                    }
                    
                    // Bottom action button with gradient fade
                    VStack(spacing: 0) {
                        // Gradient fade
                        LinearGradient(
                            colors: [AppColors.background.opacity(0), AppColors.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        
                        // Button container
                        VStack {
                            Button(action: addExpense) {
                                HStack {
                                    if isCreating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Add Expense")
                                            .font(AppFonts.bodyMedium)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: 52)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            isFormValid ?
                                            LinearGradient(
                                                colors: [AppColors.accentGradientStart, AppColors.accentGradientEnd],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [AppColors.tertiaryBackground, AppColors.tertiaryBackground],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                            }
                            .disabled(!isFormValid || isCreating)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .background(AppColors.background)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Set defaults
            if !group.participants.isEmpty {
                selectedPaidBy = group.participants[0]
                selectedParticipants = Set(group.participants)
            }
        }
        .fullScreenCover(isPresented: $showingAmountPad) {
            ModernAmountPad(amount: $totalAmount, currency: group.currency)
        }
    }
    
    private var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Cancel")
                        .font(AppFonts.bodyMedium)
                }
                .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text("New Expense")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            // Placeholder for balance
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Cancel")
                    .font(AppFonts.bodyMedium)
            }
            .foregroundColor(AppColors.secondaryText)
            .opacity(0) // Hidden but maintains spacing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.background)
    }
    
    // MARK: - Split Type Selector and Content
    
    private var splitTypeSelector: some View {
        HStack(spacing: 0) {
            SplitTabButton(title: "Even", isSelected: selectedSplitType == .equal) {
                withAnimation { selectedSplitType = .equal }
            }
            
            SplitTabButton(title: "Percentages", isSelected: selectedSplitType == .percentage) {
                withAnimation { selectedSplitType = .percentage }
            }
            
            SplitTabButton(title: "Custom", isSelected: selectedSplitType == .custom) {
                withAnimation { selectedSplitType = .custom }
            }
        }
        .padding(4)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var splitContent: some View {
        switch selectedSplitType {
        case .equal:
            EvenSplitView(
                participants: group.participants,
                selectedParticipants: $selectedParticipants,
                totalAmount: totalAmount,
                currency: group.currency
            )
        case .percentage:
            PercentageSplitView(
                participants: group.participants,
                selectedParticipants: $selectedParticipants,
                participantPercentages: $participantPercentages,
                totalAmount: totalAmount,
                currency: group.currency
            )
        case .custom:
            CustomSplitView(
                participants: group.participants,
                selectedParticipants: $selectedParticipants,
                participantCustomAmounts: $participantCustomAmounts,
                currency: group.currency,
                totalAmount: totalAmount
            )
        }
    }
    
    private func calculateSplitAmount() -> Double {
        guard !selectedParticipants.isEmpty else { return 0 }
        guard let amount = Double(totalAmount), amount > 0 else { return 0 }
        let splitAmount = amount / Double(selectedParticipants.count)
        return splitAmount.safeValue
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func addExpense() {
        guard let amount = Double(totalAmount), isFormValid else { return }
        
        isCreating = true
        Task {
            await expenseViewModel.createExpense(
                groupID: group.id,
                description: description,
                totalAmount: amount,
                paidBy: selectedPaidBy,
                paidByID: group.participantID(for: selectedPaidBy) ?? UUID().uuidString,
                splitType: .equal,
                category: selectedCategory,
                participantNames: Array(selectedParticipants)
            )
            
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void
    
    private var categoryColor: Color {
        switch category {
        case .food: return AppColors.categoryFood
        case .transportation: return AppColors.categoryTransport
        case .entertainment: return AppColors.categoryEntertainment
        case .utilities: return AppColors.categoryUtilities
        case .rent: return AppColors.categoryRent
        case .shopping: return AppColors.categoryShopping
        case .travel: return AppColors.categoryTravel
        case .other: return AppColors.categoryOther
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? categoryColor : AppColors.tertiaryBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: category.icon)
                            .font(.title3)
                            .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                    )
                
                Text(category.rawValue)
                    .font(AppFonts.caption)
                    .foregroundColor(isSelected ? AppColors.primaryText : AppColors.secondaryText)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct PayerChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(AppFonts.bodyMedium)
                .foregroundColor(isSelected ? .white : AppColors.primaryText)
                .frame(maxWidth: .infinity, maxHeight: 48)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AppColors.accent : AppColors.tertiaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.clear : AppColors.borderColor, lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct ParticipantToggle: View {
    let name: String
    let isSelected: Bool
    let amount: Double
    let currency: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(name.prefix(2).uppercased())
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.accent)
                    )
                
                Text(name)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if isSelected && amount > 0 {
                    Text(formatCurrency(amount))
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryText)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct ModernAmountPad: View {
    @Binding var amount: String
    let currency: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputAmount = ""
    
    let buttons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                    
                    Spacer()
                    
                    Button("Done") {
                        amount = inputAmount
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                    .disabled(inputAmount.isEmpty || (Double(inputAmount) ?? 0) <= 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Spacer()
                
                // Amount display
                VStack(spacing: 8) {
                    Text(currency)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text(inputAmount.isEmpty ? "0.00" : inputAmount)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Number pad
                VStack(spacing: 16) {
                    ForEach(buttons, id: \.self) { row in
                        HStack(spacing: 16) {
                            ForEach(row, id: \.self) { button in
                                AmountPadButton(
                                    title: button,
                                    action: { handleButtonPress(button) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            inputAmount = amount
        }
    }
    
    private func handleButtonPress(_ button: String) {
        switch button {
        case "⌫":
            if !inputAmount.isEmpty {
                inputAmount.removeLast()
            }
        case ".":
            if !inputAmount.contains(".") {
                if inputAmount.isEmpty {
                    inputAmount = "0."
                } else {
                    inputAmount += "."
                }
            }
        default:
            if inputAmount == "0" && button != "." {
                inputAmount = button
            } else {
                inputAmount += button
            }
        }
    }
}

struct AmountPadButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, maxHeight: 64)
                .frame(height: 64)
                .background(
                    Circle()
                        .fill(AppColors.tertiaryBackground)
                )
        }
    }
}

// MARK: - Split Tab Button

struct SplitTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.captionMedium)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: 44)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AppColors.accent : Color.clear)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Split Views

struct EvenSplitView: View {
    let participants: [String]
    @Binding var selectedParticipants: Set<String>
    let totalAmount: String
    let currency: String
    
    private var splitAmount: Double {
        guard !selectedParticipants.isEmpty else { return 0 }
        guard let amount = Double(totalAmount), amount.isFinite, amount >= 0 else { return 0 }
        let participantCount = Double(selectedParticipants.count)
        guard participantCount > 0 else { return 0 }
        let result = amount / participantCount
        return result.isFinite ? result : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(participants, id: \.self) { participant in
                ParticipantToggle(
                    name: participant,
                    isSelected: selectedParticipants.contains(participant),
                    amount: splitAmount,
                    currency: currency,
                    action: {
                        if selectedParticipants.contains(participant) {
                            selectedParticipants.remove(participant)
                        } else {
                            selectedParticipants.insert(participant)
                        }
                    }
                )
            }
        }
    }
}

struct PercentageSplitView: View {
    let participants: [String]
    @Binding var selectedParticipants: Set<String>
    @Binding var participantPercentages: [String: Double]
    let totalAmount: String
    let currency: String
    
    private var totalPercentage: Double {
        let total = participantPercentages.values.reduce(0) { result, value in
            let safeValue = value.isFinite ? value : 0
            return result + safeValue
        }
        return total.isFinite ? total : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(participants, id: \.self) { participant in
                PercentageParticipantRow(
                    name: participant,
                    isSelected: selectedParticipants.contains(participant),
                    percentage: Binding(
                        get: { participantPercentages[participant] ?? 0 },
                        set: { participantPercentages[participant] = $0 }
                    ),
                    totalAmount: Double(totalAmount) ?? 0,
                    currency: currency,
                    onToggle: {
                        if selectedParticipants.contains(participant) {
                            selectedParticipants.remove(participant)
                            participantPercentages[participant] = 0
                        } else {
                            selectedParticipants.insert(participant)
                            // Auto-assign percentage based on remaining
                            let remaining = 100 - totalPercentage
                            if remaining > 0 {
                                participantPercentages[participant] = remaining
                            } else {
                                participantPercentages[participant] = 0
                            }
                        }
                    }
                )
            }
            
            // Total percentage indicator
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: totalPercentage == 100 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(totalPercentage == 100 ? AppColors.success : AppColors.error)
                    
                    Text("Total: \(String(format: "%.1f", totalPercentage))%")
                        .font(AppFonts.captionMedium)
                        .foregroundColor(totalPercentage == 100 ? AppColors.success : AppColors.error)
                    
                    if totalPercentage != 100 {
                        Text("(Must equal 100%)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(totalPercentage == 100 ? AppColors.success.opacity(0.1) : AppColors.error.opacity(0.1))
            )
        }
    }
}

struct CustomSplitView: View {
    let participants: [String]
    @Binding var selectedParticipants: Set<String>
    @Binding var participantCustomAmounts: [String: String]
    let currency: String
    let totalAmount: String
    
    private var totalCustomAmount: Double {
        let total = participantCustomAmounts.compactMapValues { Double($0) }.values.reduce(0) { result, value in
            let safeValue = value.isFinite ? value : 0
            return result + safeValue
        }
        return total.isFinite ? total : 0
    }
    
    private var targetAmount: Double {
        guard let amount = Double(totalAmount), amount.isFinite, amount >= 0 else { return 0 }
        return amount
    }
    
    private var isValidTotal: Bool {
        abs(totalCustomAmount - targetAmount) < 0.01
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(participants, id: \.self) { participant in
                CustomAmountParticipantRow(
                    name: participant,
                    isSelected: selectedParticipants.contains(participant),
                    amount: Binding(
                        get: { participantCustomAmounts[participant] ?? "" },
                        set: { participantCustomAmounts[participant] = $0 }
                    ),
                    currency: currency,
                    onToggle: {
                        if selectedParticipants.contains(participant) {
                            selectedParticipants.remove(participant)
                            participantCustomAmounts[participant] = ""
                        } else {
                            selectedParticipants.insert(participant)
                        }
                    }
                )
            }
            
            // Total amount indicator
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isValidTotal ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(isValidTotal ? AppColors.success : AppColors.error)
                    
                    Text("Total: \(formatCurrency(totalCustomAmount))")
                        .font(AppFonts.captionMedium)
                        .foregroundColor(isValidTotal ? AppColors.success : AppColors.error)
                    
                    if !isValidTotal {
                        Text("(Must equal \(formatCurrency(targetAmount)))")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isValidTotal ? AppColors.success.opacity(0.1) : AppColors.error.opacity(0.1))
            )
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct PercentageParticipantRow: View {
    let name: String
    let isSelected: Bool
    @Binding var percentage: Double
    let totalAmount: Double
    let currency: String
    let onToggle: () -> Void
    
    private var calculatedAmount: Double {
        guard totalAmount.isFinite, percentage.isFinite else { return 0 }
        guard totalAmount >= 0, percentage >= 0 else { return 0 }
        let result = totalAmount * (percentage / 100)
        return result.isFinite ? result : 0
    }
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(name.prefix(2).uppercased())
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.accent)
                        )
                    
                    Text(name)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryText)
                }
            }
            .disabled(!isSelected)
            
            if isSelected {
                VStack(spacing: 4) {
                    HStack {
                        TextField("0", value: $percentage, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .textFieldStyle(.plain)
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("%")
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Text(formatCurrency(calculatedAmount))
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.leading, 12)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        guard amount.isFinite else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct CustomAmountParticipantRow: View {
    let name: String
    let isSelected: Bool
    @Binding var amount: String
    let currency: String
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(name.prefix(2).uppercased())
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.accent)
                        )
                    
                    Text(name)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.tertiaryText)
                }
            }
            .disabled(!isSelected)
            
            if isSelected {
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(8)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}