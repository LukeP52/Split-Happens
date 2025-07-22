// ModernCreateGroupView.swift
import SwiftUI

struct ModernCreateGroupView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var participants: [String] = []
    @State private var newParticipant = ""
    @State private var selectedCurrency = "USD"
    @State private var isCreating = false
    @State private var showingCurrencyPicker = false
    
    let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "CNY"]
    
    private var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        participants.count >= 2
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom navigation bar
                customNavBar
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create New Group")
                                .font(AppFonts.largeTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Set up a group to start splitting expenses")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.top, 20)
                        
                        // Group name input
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Group Name", systemImage: "text.quote")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(AppColors.secondaryText)
                            
                            TextField("Enter group name", text: $groupName)
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
                        
                        // Currency selector
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Currency", systemImage: "dollarsign.circle")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Button(action: { showingCurrencyPicker.toggle() }) {
                                HStack {
                                    Text(selectedCurrency)
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                .padding(16)
                                .background(AppColors.tertiaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.borderColor, lineWidth: 1)
                                )
                            }
                        }
                        
                        // Participants section
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Participants", systemImage: "person.2.fill")
                                .font(AppFonts.captionMedium)
                                .foregroundColor(AppColors.secondaryText)
                            
                            // Add participant input
                            HStack(spacing: 12) {
                                TextField("Add participant name", text: $newParticipant)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.primaryText)
                                    .padding(16)
                                    .background(AppColors.tertiaryBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.borderColor, lineWidth: 1)
                                    )
                                    .onSubmit {
                                        addParticipant()
                                    }
                                
                                Button(action: addParticipant) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(AppColors.accent)
                                }
                                .disabled(newParticipant.isEmpty)
                            }
                            
                            // Participants list
                            VStack(spacing: 12) {
                                ForEach(participants, id: \.self) { participant in
                                    ParticipantRow(
                                        name: participant,
                                        onDelete: {
                                            withAnimation {
                                                participants.removeAll { $0 == participant }
                                            }
                                        }
                                    )
                                }
                            }
                            
                            if participants.count < 2 {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(AppColors.warning)
                                    
                                    Text("Add at least 2 participants")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Bottom action button
                VStack {
                    Button(action: createGroup) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Create Group")
                                    .font(AppFonts.bodyMedium)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
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
                .padding(.vertical, 20)
                .background(
                    AppColors.background
                        .overlay(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.background.opacity(0), AppColors.background],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 20)
                                .offset(y: -20),
                            alignment: .top
                        )
                )
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerView(selectedCurrency: $selectedCurrency)
        }
    }
    
    private var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Cancel")
                        .font(AppFonts.bodyMedium)
                }
                .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func addParticipant() {
        let trimmedName = newParticipant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !participants.contains(trimmedName) else { return }
        
        withAnimation {
            participants.append(trimmedName)
            newParticipant = ""
        }
    }
    
    private func createGroup() {
        guard isFormValid else { return }
        
        isCreating = true
        Task {
            await groupViewModel.createGroup(
                name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                participants: participants,
                currency: selectedCurrency
            )
            
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

struct ParticipantRow: View {
    let name: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(name.prefix(2).uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.accent)
                )
            
            Text(name)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.error)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}

struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    
    let currencies = [
        ("USD", "US Dollar", "$"),
        ("EUR", "Euro", "€"),
        ("GBP", "British Pound", "£"),
        ("CAD", "Canadian Dollar", "C$"),
        ("AUD", "Australian Dollar", "A$"),
        ("JPY", "Japanese Yen", "¥"),
        ("CHF", "Swiss Franc", "CHF"),
        ("CNY", "Chinese Yuan", "¥")
    ]
    
    var body: some View {
        NavigationView {
            List(currencies, id: \.0) { currency in
                Button(action: {
                    selectedCurrency = currency.0
                    dismiss()
                }) {
                    HStack {
                        Text(currency.2)
                            .font(AppFonts.title3)
                            .foregroundColor(AppColors.accent)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currency.0)
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text(currency.1)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        if selectedCurrency == currency.0 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppColors.cardBackground)
            }
            .listStyle(.plain)
            .background(AppColors.background)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}