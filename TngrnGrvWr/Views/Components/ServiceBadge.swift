import SwiftUI

struct ServiceBadge: View {
    let service: StreamingService

    var body: some View {
        switch service {
        case .appleMusic:
            Image(systemName: "apple.logo")
                .font(.caption2)
                .foregroundStyle(.yellow)
                .shadow(color: .orange.opacity(0.6), radius: 2)
        case .spotify:
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.green)
        case .none:
            EmptyView()
        }
    }
}
