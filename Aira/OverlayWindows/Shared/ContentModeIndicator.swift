import SwiftUI

/// Small badge shown on hover in Pill windows indicating Voice-Sync vs Manual mode.
struct ContentModeIndicator: View {
  let systemImageName: String
  let isVisible: Bool

  var body: some View {
    Group {
      if isVisible {
        Image(systemName: systemImageName)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.white)
          .padding(5)
          .background(Color.black.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .transition(.opacity)
      }
    }
  }
}

enum PillContentMode: Equatable, Codable {
  case voiceSync
  case manual(scriptId: UUID)

  private enum CodingKeys: String, CodingKey { case type, scriptId }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    switch try c.decode(String.self, forKey: .type) {
    case "manual":
      self = .manual(scriptId: try c.decode(UUID.self, forKey: .scriptId))
    default:
      self = .voiceSync
    }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .voiceSync:
      try c.encode("voiceSync", forKey: .type)
    case .manual(let id):
      try c.encode("manual", forKey: .type)
      try c.encode(id, forKey: .scriptId)
    }
  }
}
