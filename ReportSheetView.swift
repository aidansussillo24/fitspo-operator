//
//  ReportSheetView.swift
//  FitSpo
//
//  Simple sheet that lets the user pick a reason and submit.
//

import SwiftUI

struct ReportSheetView: View {

    let postId: String
    @Binding var isPresented: Bool

    @State private var selectedReason: ReportReason? = nil
    @State private var isSubmitting = false
    @State private var showThanks   = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this post?") {
                    ForEach(ReportReason.allCases) { reason in
                        HStack {
                            Text(reason.rawValue)
                            Spacer()
                            if selectedReason == reason {
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedReason = reason }
                    }
                }
            }
            .navigationTitle("Report Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .disabled(selectedReason == nil || isSubmitting)
                }
            }
            .alert("Thank you",
                   isPresented: $showThanks) {
                Button("Close") { isPresented = false }
            } message: {
                Text("Your report has been submitted.")
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func submit() {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        NetworkService.shared.submitReport(postId: postId,
                                           reason: reason) { res in
            DispatchQueue.main.async {
                isSubmitting = false
                switch res {
                case .success:
                    showThanks = true
                case .failure(let err):
                    // Very lightweight error handling
                    print("Report failed:", err.localizedDescription)
                    isPresented = false
                }
            }
        }
    }
}
