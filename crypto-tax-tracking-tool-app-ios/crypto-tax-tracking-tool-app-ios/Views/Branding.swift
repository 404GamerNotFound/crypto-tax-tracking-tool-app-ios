import SwiftUI

/// Local artwork only. Accessible names and all product copy remain native text.
struct BrandLogo: View {
    var size: CGFloat = 56
    var body: some View {
        Image("CryptoBuchLogo")
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 14) {
            BrandLogo()
            VStack(alignment: .leading, spacing: 3) {
                Text("CryptoBuch").font(.title2.weight(.bold))
                Text("Dein digitales Buchungsjournal")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct BrandIllustration: View {
    var maximumHeight: CGFloat = 190
    var body: some View {
        Image("CryptoBuchJournal")
            .resizable().interpolation(.high).scaledToFit()
            .frame(maxWidth: 420, maxHeight: maximumHeight)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

struct BrandEmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            BrandIllustration(maximumHeight: 160)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
