//
//  QuickAddExpenseView.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import SwiftUI

struct QuickAddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var expenseViewModel = ExpenseViewModel()
    
    @State private var amount: Double = 0
    @State private var description = ""
    @State private var selectedGroup: Group?
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var splitEqually = true
    @State private var paidByMe = true
    @State private var selectedPayer: String = ""
    
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isDescriptionFocused: Bool
    
    private var isValid: Bool {
        amount > 0 && 
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedGroup != nil
    }
    
    private var recentGroups: [Group] {
        Array(groupViewModel.groups.prefix(3))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                ModernGradientBackground()
                    .ignoresSafeArea()
                
                KeyboardAwareScrollView {
                    VStack(spacing: 0) {
                        // Amount input section
                        amountInputSection
                            .padding(.vertical, 40)
                        
                        // Form fields
                        VStack(spacing: 24) {
                            descriptionSection
                            groupSelectionSection
                            categorySection
                            splitOptionsSection
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveExpense()
                        }
                    }
                    .foregroundColor(isValid ? AppColors.accent : AppColors.secondaryText)
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .keyboardToolbar(
                onDone: {
                    if isAmountFocused {
                        isDescriptionFocused = true
                    } else {
                        hideKeyboard()
                    }
                }
            )
            .withErrorHandling()
        }
        .task {
            await groupViewModel.loadGroups()
            if let firstGroup = groupViewModel.groups.first {
                selectedGroup = firstGroup
                selectedPayer = firstGroup.participants.first ?? ""
            }
        }
    }
    
    // MARK: - Amount Input Section
    
    private var amountInputSection: some View {
        VStack(spacing: 16) {
            Text("How much?")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            HStack {
                Text("$")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
                
                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .foregroundColor(AppColors.accent)
                    .frame(minWidth: 100)
            }
            .onTapGesture {
                isAmountFocused = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        SmartTextField(
            title: "For what?",
            text: $description,
            placeholder: "Enter a description",
            onCommit: {
                hideKeyboard()
            }
        )
        .focused($isDescriptionFocused)
    }
    
    // MARK: - Group Selection Section
    
    private var groupSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("With whom?")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            if !recentGroups.isEmpty {
                VStack(spacing: 12) {
                    // Quick group selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentGroups) { group in
                                GroupChip(
                                    group: group,
                                    isSelected: selectedGroup?.id == group.id
                                ) {
                                    selectedGroup = group
                                    selectedPayer = group.participants.first ?? ""
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                    
                    // "Other group" button
                    Button("Choose different group") {
                        // Show group picker
                    }
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.accent)
                }
            } else {
                // Create group button if no groups exist
                Button("Create your first group") {
                    // Navigate to group creation
                }
                .buttonStyle(ModernAccentButton())
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        CategorySelectionChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Split Options Section
    
    private var splitOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Split & Payment")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            VStack(spacing: 12) {
                // Split options
                HStack(spacing: 12) {
                    SplitOptionButton(
                        title: "Split Equally",
                        subtitle: "Everyone pays equal share",
                        icon: "equal.circle.fill",
                        isSelected: splitEqually,
                        action: { splitEqually = true }
                    )
                    
                    SplitOptionButton(
                        title: "I Paid Full",
                        subtitle: "Others owe me",
                        icon: "person.circle.fill",
                        isSelected: !splitEqually,
                        action: { splitEqually = false }
                    )
                }
                
                // Payer selection
                if let group = selectedGroup, !group.participants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Who paid?")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(group.participants, id: \.self) { participant in
                                    ParticipantChip(
                                        name: participant,
                                        isSelected: selectedPayer == participant
                                    ) {
                                        selectedPayer = participant
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.horizontal, -20)
                    }
                }
            }
            .padding(20)
            .background(AppColors.cardBackground)
            .modernCard()
        }
    }
    
    // MARK: - Actions
    
    private func saveExpense() async {
        guard let group = selectedGroup, !selectedPayer.isEmpty else { return }
        
        let payerID = group.participantIDs[safe: group.participants.firstIndex(of: selectedPayer) ?? 0] ?? UUID().uuidString
        
        await expenseViewModel.createExpense(
            groupID: group.id,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: amount,
            paidBy: selectedPayer,
            paidByID: payerID,
            splitType: splitEqually ? .equal : .custom,
            category: selectedCategory,
            participantNames: group.participants
        )
        
        if expenseViewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct GroupChip: View {
    let group: Group
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                PersonAvatar(name: group.name, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(isSelected ? .white : AppColors.primaryText)
                        .lineLimit(1)
                    
                    Text("\(group.participants.count) people")
                        .font(AppFonts.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.secondaryText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppColors.accent : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderColor,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct CategorySelectionChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : category.swiftUIColor)
                
                Text(category.displayName)
                    .font(AppFonts.caption)
                    .foregroundColor(isSelected ? .white : AppColors.primaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? category.swiftUIColor : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderColor,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SplitOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : AppColors.accent)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(AppFonts.captionMedium)
                        .foregroundColor(isSelected ? .white : AppColors.primaryText)
                    
                    Text(subtitle)
                        .font(AppFonts.footnote)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppColors.accent : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderColor,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ParticipantChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                PersonAvatar(name: name, size: 24)
                
                Text(name)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(isSelected ? .white : AppColors.primaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AppColors.accent : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderColor,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    QuickAddExpenseView()
}