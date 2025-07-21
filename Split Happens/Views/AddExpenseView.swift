//
//  AddExpenseView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/18/25.
//

import SwiftUI

struct AddExpenseView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @StateObject private var offlineManager = OfflineStorageManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var description = ""
    @State private var totalAmount = ""
    @State private var selectedPaidBy = ""
    @State private var selectedSplitType = SplitType.equal
    @State private var selectedCategory = ExpenseCategory.other
    @State private var selectedDate = Date()
    @State private var selectedParticipants: Set<String> = []
    @State private var customSplits: [String: Double] = [:]
    @State private var percentageSplits: [String: Double] = [:]
    @State private var isCreating = false
    
    private var isValidForm: Bool {
        let isBasicValid = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !totalAmount.isEmpty &&
            (Double(totalAmount) ?? 0) > 0 &&
            !selectedPaidBy.isEmpty &&
            !selectedParticipants.isEmpty
        
        guard isBasicValid else { return false }
        
        switch selectedSplitType {
        case .equal:
            return true
        case .percentage:
            let totalPercentage = percentageSplits.values.reduce(0) { total, value in
                guard value.isFinite && !value.isNaN else { return total }
                return total + value
            }
            let safeTotal = totalPercentage.isFinite && !totalPercentage.isNaN ? totalPercentage : 0
            return abs(safeTotal - 100.0) < 0.01
        case .custom:
            let totalCustom = customSplits.values.reduce(0) { total, value in
                guard value.isFinite && !value.isNaN else { return total }
                return total + value
            }
            let safeTotal = totalCustom.isFinite && !totalCustom.isNaN ? totalCustom : 0
            let targetAmount = Double(totalAmount) ?? 0
            return abs(safeTotal - targetAmount) < 0.01
        }
    }
    
    private var validationErrors: [String] {
        var errors: [String] = []
        
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Description is required")
        }
        
        if totalAmount.isEmpty || (Double(totalAmount) ?? 0) <= 0 {
            errors.append("Valid amount is required")
        }
        
        if selectedPaidBy.isEmpty {
            errors.append("Select who paid")
        }
        
        if selectedParticipants.isEmpty {
            errors.append("Select at least one participant")
        }
        
        switch selectedSplitType {
        case .percentage:
            let totalPercentage = percentageSplits.values.reduce(0) { total, value in
                guard value.isFinite && !value.isNaN else { return total }
                return total + value
            }
            let safeTotal = totalPercentage.isFinite && !totalPercentage.isNaN ? totalPercentage : 0
            if abs(safeTotal - 100.0) >= 0.01 {
                errors.append("Percentages must add up to 100%")
            }
        case .custom:
            let totalCustom = customSplits.values.reduce(0) { total, value in
                guard value.isFinite && !value.isNaN else { return total }
                return total + value
            }
            let safeTotal = totalCustom.isFinite && !totalCustom.isNaN ? totalCustom : 0
            let targetAmount = Double(totalAmount) ?? 0
            if abs(safeTotal - targetAmount) >= 0.01 {
                errors.append("Custom amounts must add up to total")
            }
        case .equal:
            break
        }
        
        return errors
    }
    
    var body: some View {
        NavigationView {
            Form {
                expenseDetailsSection
                paymentSection
                splitConfigurationSection
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addExpense()
                    }
                    .disabled(!isValidForm || isCreating)
                }
            }
            .onAppear {
                Task { @MainActor in
                    setupDefaults()
                }
            }
            .onReceive(expenseViewModel.$errorMessage) { errorMessage in
                guard let message = errorMessage else { return }
                Task { @MainActor in
                    alertManager.showExpenseError(message)
                    expenseViewModel.clearError()
                }
            }
        }
    }
    
    private var expenseDetailsSection: some View {
        Section {
            TextField("What was this expense for?", text: $description)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Amount")
                Spacer()
                TextField("0.00", text: $totalAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
        } header: {
            Text("Expense Details")
        }
    }
    
    private var paymentSection: some View {
        Section {
            Picker("Who paid?", selection: $selectedPaidBy) {
                if selectedPaidBy.isEmpty {
                    Text("Select who paid").tag("")
                }
                ForEach(group.participants, id: \.self) { participant in
                    Label(participant, systemImage: "person.fill")
                        .tag(participant)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Split Type", selection: $selectedSplitType) {
                ForEach(SplitType.allCases, id: \.self) { splitType in
                    VStack(alignment: .leading) {
                        Text(splitType.displayName)
                        Text(splitType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(splitType)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedSplitType) { _ in
                setupSplitDefaults()
            }
        } header: {
            Text("Payment")
        }
    }
    
    private var splitConfigurationSection: some View {
        SwiftUI.Group {
            switch selectedSplitType {
            case .equal:
                equalSplitSection
            case .percentage:
                percentageSplitSection
            case .custom:
                customSplitSection
            }
        }
    }
    
    private var equalSplitSection: some View {
        Section {
            ForEach(group.participants, id: \.self) { participant in
                ParticipantSelectionRow(
                    participant: participant,
                    isSelected: selectedParticipants.contains(participant),
                    equalAmount: calculateEqualAmount(),
                    currency: group.currency
                ) {
                    toggleParticipant(participant)
                }
            }
        } header: {
            Text("Participants (\(selectedParticipants.count))")
        } footer: {
            if !selectedParticipants.isEmpty {
                Text("Each person pays \(formatCurrency(calculateEqualAmount()))")
            }
        }
    }
    
    private func calculateEqualAmount() -> Double {
        guard !selectedParticipants.isEmpty else { return 0 }
        guard let amount = Double(totalAmount), amount > 0 else { return 0 }
        let equalAmount = amount / Double(selectedParticipants.count)
        return equalAmount.isFinite ? equalAmount : 0
    }
    
    private var percentageSplitSection: some View {
        Section {
            ForEach(group.participants, id: \.self) { participant in
                PercentageSplitRow(
                    participant: participant,
                    percentage: Binding(
                        get: { percentageSplits[participant] ?? 0 },
                        set: { percentageSplits[participant] = $0 }
                    ),
                    totalAmount: Double(totalAmount) ?? 0,
                    currency: group.currency
                )
            }
        } header: {
            Text("Percentage Split")
        }
    }
    
    private var customSplitSection: some View {
        Section {
            ForEach(group.participants, id: \.self) { participant in
                CustomSplitRow(
                    participant: participant,
                    amount: Binding(
                        get: { customSplits[participant] ?? 0 },
                        set: { customSplits[participant] = $0 }
                    ),
                    currency: group.currency
                )
            }
        } header: {
            Text("Custom Split")
        }
    }
    
    private var validationSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { error in
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        } header: {
            Text("Issues to Fix")
        }
    }
    
    private func setupDefaults() {
        if !group.participants.isEmpty {
            selectedPaidBy = group.participants[0]
            selectedParticipants = Set(group.participants)
        }
        setupSplitDefaults()
    }
    
    private func setupSplitDefaults() {
        let amount = Double(totalAmount) ?? 0
        let participantCount = Double(selectedParticipants.count)
        
        switch selectedSplitType {
        case .equal:
            break
        case .percentage:
            percentageSplits.removeAll()
            if participantCount > 0 {
                let equalPercentage = NaNDetector.shared.validate(100.0 / participantCount, context: "AddExpenseView.setupSplitDefaults.equalPercentage")
                for participant in selectedParticipants {
                    percentageSplits[participant] = equalPercentage
                }
            }
        case .custom:
            customSplits.removeAll()
            if participantCount > 0 {
                let equalAmount = NaNDetector.shared.validate(amount / participantCount, context: "AddExpenseView.setupSplitDefaults.equalAmount")
                for participant in selectedParticipants {
                    customSplits[participant] = equalAmount
                }
            }
        }
    }
    
    private func toggleParticipant(_ participant: String) {
        if selectedParticipants.contains(participant) {
            selectedParticipants.remove(participant)
        } else {
            selectedParticipants.insert(participant)
        }
        setupSplitDefaults()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        guard amount.isFinite && !amount.isNaN else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    private func addExpense() {
        guard let amount = Double(totalAmount), isValidForm else { return }
        
        isCreating = true
        
        var expense = Expense(
            groupReference: group.id,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: amount,
            paidBy: selectedPaidBy,
            paidByID: group.participantID(for: selectedPaidBy) ?? UUID().uuidString,
            splitType: selectedSplitType,
            date: selectedDate,
            category: selectedCategory,
            participantNames: Array(selectedParticipants)
        )
        
        switch selectedSplitType {
        case .equal:
            expense.generateEqualSplits()
        case .percentage:
            for (participant, percentage) in percentageSplits {
                expense.updateSplitForParticipant(participant, percentage: percentage)
            }
        case .custom:
            for (participant, amount) in customSplits {
                expense.updateSplitForParticipant(participant, amount: amount)
            }
        }
        
        Task {
            if offlineManager.isOnline {
                await expenseViewModel.createExpense(
                    groupID: expense.groupReference,
                    description: expense.description,
                    totalAmount: expense.totalAmount,
                    paidBy: expense.paidBy,
                    paidByID: expense.paidByID,
                    splitType: expense.splitType,
                    category: expense.category,
                    participantNames: expense.participantNames
                )
            } else {
                // Save offline and queue for sync
                offlineManager.saveExpenseOffline(expense)
                await MainActor.run {
                    expenseViewModel.expenses.append(expense)
                }
            }
            
            await MainActor.run {
                isCreating = false
                if expenseViewModel.errorMessage == nil || !offlineManager.isOnline {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Supporting UI Components

struct ParticipantSelectionRow: View {
    let participant: String
    let isSelected: Bool
    let equalAmount: Double
    let currency: String
    let onToggle: () -> Void
    
    private var safeAmount: Double {
        guard equalAmount.isFinite && equalAmount >= 0 else { return 0 }
        return equalAmount
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Label(participant, systemImage: "person.fill")
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    VStack(alignment: .trailing, spacing: 2) {
                        if safeAmount > 0 {
                            Text(formatCurrency(safeAmount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct PercentageSplitRow: View {
    let participant: String
    @Binding var percentage: Double
    let totalAmount: Double
    let currency: String
    
    private var calculatedAmount: Double {
        guard totalAmount.isFinite && totalAmount > 0 else { return 0 }
        guard percentage.isFinite && percentage >= 0 else { return 0 }
        let amount = totalAmount * percentage / 100
        return amount.isFinite ? amount : 0
    }
    
    var body: some View {
        HStack {
            Label(participant, systemImage: "person.fill")
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                TextField("0", value: $percentage, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                
                if calculatedAmount > 0 {
                    Text("(\(formatCurrency(calculatedAmount)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("%")
                .foregroundColor(.secondary)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct CustomSplitRow: View {
    let participant: String
    @Binding var amount: Double
    let currency: String
    
    var body: some View {
        HStack {
            Label(participant, systemImage: "person.fill")
            
            Spacer()
            
            TextField("0.00", value: $amount, format: .currency(code: currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct AmountInputView: View {
    @Binding var totalAmount: String
    let currency: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputAmount = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Enter Amount")
                        .font(.headline)
                    
                    Text(formatCurrency(Double(inputAmount) ?? 0))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding()
                
                NumberPadView(input: $inputAmount)
                
                Spacer()
            }
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        totalAmount = inputAmount
                        dismiss()
                    }
                    .disabled(inputAmount.isEmpty || (Double(inputAmount) ?? 0) <= 0)
                }
            }
            .onAppear {
                Task { @MainActor in
                    inputAmount = totalAmount
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct NumberPadView: View {
    @Binding var input: String
    
    let buttons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { button in
                        NumberPadButton(
                            title: button,
                            action: { handleButtonPress(button) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func handleButtonPress(_ button: String) {
        switch button {
        case "⌫":
            if !input.isEmpty {
                input.removeLast()
            }
        case ".":
            if !input.contains(".") {
                if input.isEmpty {
                    input = "0."
                } else {
                    input += "."
                }
            }
        default:
            if input == "0" && button != "." {
                input = button
            } else {
                input += button
            }
        }
    }
}

struct NumberPadButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 80, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}

struct EditExpenseView: View {
    let expense: Expense
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var description: String
    @State private var totalAmount: String
    @State private var selectedPaidBy: String
    @State private var selectedSplitType: SplitType
    @State private var selectedCategory: ExpenseCategory
    @State private var selectedDate: Date
    @State private var selectedParticipants: Set<String>
    
    init(expense: Expense, group: Group, expenseViewModel: ExpenseViewModel) {
        self.expense = expense
        self.group = group
        self.expenseViewModel = expenseViewModel
        
        _description = State(initialValue: expense.description)
        _totalAmount = State(initialValue: String(format: "%.2f", expense.totalAmount))
        _selectedPaidBy = State(initialValue: expense.paidBy)
        _selectedSplitType = State(initialValue: expense.splitType)
        _selectedCategory = State(initialValue: expense.category)
        _selectedDate = State(initialValue: expense.date)
        _selectedParticipants = State(initialValue: Set(expense.participantNames))
    }
    
    var isValidForm: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !totalAmount.isEmpty &&
        Double(totalAmount) != nil &&
        Double(totalAmount)! > 0 &&
        !selectedPaidBy.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Expense Details") {
                    TextField("Description", text: $description)
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $totalAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section("Payment") {
                    Picker("Paid by", selection: $selectedPaidBy) {
                        ForEach(group.participants, id: \.self) { participant in
                            Text(participant).tag(participant)
                        }
                    }
                    
                    Picker("Split Type", selection: $selectedSplitType) {
                        ForEach(SplitType.allCases, id: \.self) { splitType in
                            Text(splitType.rawValue).tag(splitType)
                        }
                    }
                }
                
                if selectedSplitType == .custom && !group.participants.isEmpty {
                    Section("Participants") {
                        ForEach(group.participants, id: \.self) { participant in
                            HStack {
                                Text(participant)
                                Spacer()
                                if selectedParticipants.contains(participant) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedParticipants.contains(participant) {
                                    selectedParticipants.remove(participant)
                                } else {
                                    selectedParticipants.insert(participant)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateExpense()
                    }
                    .disabled(!isValidForm)
                }
            }
        }
    }
    
    private func updateExpense() {
        guard let amount = Double(totalAmount),
              !selectedPaidBy.isEmpty else { return }
        
        var updatedExpense = expense
        updatedExpense.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedExpense.totalAmount = amount
        updatedExpense.paidBy = selectedPaidBy
        updatedExpense.splitType = selectedSplitType
        updatedExpense.category = selectedCategory
        updatedExpense.date = selectedDate
        updatedExpense.participantNames = Array(selectedParticipants)
        
        Task {
            await expenseViewModel.updateExpense(updatedExpense)
            dismiss()
        }
    }
}

#Preview {
    AddExpenseView(
        group: Group(name: "Sample Group", participants: ["Alice", "Bob", "Charlie"]),
        expenseViewModel: ExpenseViewModel()
    )
} 