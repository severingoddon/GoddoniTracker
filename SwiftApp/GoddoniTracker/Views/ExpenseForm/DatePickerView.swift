import SwiftUI

struct DatePickerView: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                DatePicker("", selection: $date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("OK")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(GTColor.accentCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Datum wählen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
