import SwiftUI

/// Painel do menu bar. Tudo que o app faz cabe aqui — não há janela principal.
struct MenuContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if state.needsAccessibility {
                accessibilityBanner
            }

            Divider()

            packPicker
            volumeSlider
            forceSection

            Divider()

            HStack {
                Button("Importar meus sons") { state.importPack() }
                Button("Abrir pasta de sons") { state.openUserPacksFolder() }
            }
            .controlSize(.small)

            HStack {
                Text("DNKEY \(Bundle.main.shortVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Sair") { NSApplication.shared.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 290)
    }

    private var header: some View {
        HStack {
            Text("DNKEY").font(.headline)
            Spacer()
            Toggle("", isOn: $state.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var accessibilityBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Precisa de permissão de Acessibilidade")
                .font(.subheadline).bold()
            Text("Sem ela o DNKEY não consegue ouvir as teclas.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Conceder permissão") { state.requestAccessibility() }
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    private var packPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Som").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $state.currentPackID) {
                ForEach(state.packs) { pack in
                    Text(pack.displayName).tag(pack.id)
                }
            }
            .labelsHidden()
        }
    }

    private var volumeSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Volume").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $state.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var forceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Responder à força da batida", isOn: $state.useForce)
                .controlSize(.small)

            HStack(spacing: 6) {
                Circle()
                    .fill(state.sensorStatus == .active ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(sensorLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if state.useForce && state.sensorStatus == .active {
                ProgressView(value: state.lastIntensity)
                    .progressViewStyle(.linear)
            }
        }
    }

    private var sensorLabel: String {
        guard state.useForce else { return "Desligado" }
        switch state.sensorStatus {
        case .active: return "Força real (acelerômetro ativo)"
        case .unavailable: return "Sem acelerômetro — intensidade fixa"
        }
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }
}
