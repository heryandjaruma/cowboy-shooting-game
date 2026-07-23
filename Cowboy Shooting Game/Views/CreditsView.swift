import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Credit: Identifiable {
        let id = UUID() // Just in case we wanna do the role role thingies
        let role: LocalizedStringResource
        let people: String
    }

    private let credits: [Credit] = [
        Credit(role: "Project Manager", people: "Ryan Firdaus"),
        Credit(role: "Technical Lead", people: "Heryan Djaruma"),
        Credit(role: "Asset Illustrator", people: "Annisa Rahmadani"),
        Credit(role: "Developers", people: "Ryan Firdaus, Heryan Djaruma, Cello Tanojo, Mark Pardede"),
        Credit(role: "UI Designers", people: "Annisa Rahmadani, Cello Tanojo"),
        Credit(role: "Music & SFX", people: "Heryan Djaruma")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .ignoresSafeArea(edges: .all)

            VStack {
                ScreenTopBar(title: "Credits") {
                    dismiss()
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(credits) { credit in
                        Text(
                            "\(Text(credit.role).foregroundStyle(Color.ternaryCSG)): \(Text(credit.people).foregroundStyle(Color.ternaryCSG.opacity(0.7)))"
                        )
                            .font(.bodyCSG)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primaryCSG)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.ternaryCSG, lineWidth: 4)
                        )
                )
                .padding(.top, 20)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    CreditsView()
}
