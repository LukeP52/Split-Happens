//
//  KeyboardHandling.swift
//  Split Happens
//
//  Created by Luke Peterson on 7/25/25.
//

import SwiftUI
import Combine

// MARK: - Keyboard Publisher

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - View Extensions

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                       to: nil, from: nil, for: nil)
    }
    
    func keyboardAdaptive() -> some View {
        ModifiedContent(
            content: self,
            modifier: KeyboardAdaptive()
        )
    }
    
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}

// MARK: - Keyboard Adaptive Modifier

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(Publishers.keyboardHeight) { height in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = height
                }
            }
    }
}

// MARK: - Keyboard Aware ScrollView

struct KeyboardAwareScrollView<Content: View>: View {
    let content: Content
    @State private var keyboardHeight: CGFloat = 0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
                .padding(.bottom, keyboardHeight)
        }
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = height
            }
        }
    }
}

// MARK: - Smart TextField

struct SmartTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var onCommit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(AppFonts.body)
                    .padding(16)
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(12)
                    .focused($isFocused)
                    .onSubmit {
                        onCommit?()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? AppColors.accent : AppColors.borderColor,
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            } else {
                TextField(placeholder, text: $text)
                    .font(AppFonts.body)
                    .padding(16)
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(12)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .onSubmit {
                        onCommit?()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? AppColors.accent : AppColors.borderColor,
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            }
        }
    }
}

// MARK: - Currency Input Field

struct CurrencyInputField: View {
    let title: String
    @Binding var amount: Double
    let placeholder: String
    
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            HStack {
                Text("$")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.leading, 16)
                
                TextField(placeholder, text: $textValue)
                    .font(AppFonts.body)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .onChange(of: textValue) { newValue in
                        // Format and validate currency input
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        let components = filtered.components(separatedBy: ".")
                        
                        if components.count <= 2 {
                            let formatted = components.count == 2 ? 
                                "\(components[0]).\(String(components[1].prefix(2)))" : filtered
                            
                            if formatted != newValue {
                                textValue = formatted
                            }
                            
                            amount = Double(formatted) ?? 0.0
                        } else if components.count > 2 {
                            // Remove extra decimal points
                            textValue = String(textValue.dropLast())
                        }
                    }
                    .onAppear {
                        if amount > 0 {
                            textValue = String(format: "%.2f", amount)
                        }
                    }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .background(AppColors.tertiaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? AppColors.accent : AppColors.borderColor,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - Toolbar Helpers

extension View {
    func keyboardToolbar(
        onDone: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    if let onCancel = onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        onDone()
                    }
                    .foregroundColor(AppColors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}