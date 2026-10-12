import SwiftUI
import SwiftData
import CCTVCore

struct DashboardView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @Query private var priceLists: [PriceList]
    @Environment(AppRouter.self) private var router
    @Environment(SettingsStore.self) private var settings

    private var openProjects: [Project] { projects.filter { $0.status.isOpen } }
    private var offeredVolume: Decimal {
        projects.filter { $0.status == .offeriert }.compactMap(\.latestOffer).reduce(Decimal(0)) { $0 + $1.recommendedTotal }
    }
    private var productCount: Int { priceLists.reduce(0) { $0 + $1.products.count } }

    private let tileColumns = [GridItem(.adaptive(minimum: 200), spacing: 16)]
    private let cardColumns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandHeader()

                if !settings.company.isComplete {
                    companyHint
                }

                LazyVGrid(columns: tileColumns, spacing: 16) {
                    StatTile(title: "Projekte total", value: "\(projects.count)", systemImage: "folder", tint: Theme.anthrazit)
                    StatTile(title: "Offen", value: "\(openProjects.count)", systemImage: "clock", tint: Theme.sonneText)
                    StatTile(title: "Offeriert (inkl. MWST)", value: Format.chf(offeredVolume), systemImage: "doc.text", tint: Theme.success)
                    StatTile(title: "Produkte in Preislisten", value: "\(productCount)", systemImage: "list.bullet.rectangle", tint: Theme.grau)
                }

                SectionHeader(title: "Schnellstart", systemImage: "bolt")
                LazyVGrid(columns: tileColumns, spacing: 16) {
                    Button {
                        router.startNewProject()
                    } label: {
                        QuickAction(title: "Neues Projekt", subtitle: "Bedarfsaufnahme vor Ort starten", systemImage: "plus.rectangle.on.folder", prominent: true)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        StorageCalculatorView()
                    } label: {
                        QuickAction(title: "Speicherrechner", subtitle: "TB und Festplatten berechnen", systemImage: "externaldrive")
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        MaintenanceCalculatorView()
                    } label: {
                        QuickAction(title: "Wartungsrechner", subtitle: "Basic, Business, Premium", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.plain)
                    Button {
                        router.section = .projects
                    } label: {
                        QuickAction(title: "Alle Projekte", subtitle: "Suchen, importieren, exportieren", systemImage: "folder")
                    }
                    .buttonStyle(.plain)
                }

                SectionHeader(title: "Zuletzt bearbeitet", systemImage: "clock.arrow.circlepath")
                if projects.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Projekte",
                        systemImage: "folder.badge.plus",
                        description: Text("Mit «Neues Projekt» erfassen Sie Kunde, Bereiche, Infrastruktur und Fotos direkt vor Ort.")
                    )
                    .card()
                } else {
                    LazyVGrid(columns: cardColumns, spacing: 16) {
                        ForEach(projects.prefix(6)) { project in
                            Button {
                                router.openProject(project.id)
                            } label: {
                                RecentProjectCard(project: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.brand(.title2))
                        .foregroundStyle(Theme.gruen)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vollständig offline")
                            .font(.brand(.headline))
                        Text("Projekte, Fotos und Preislisten werden ausschliesslich lokal auf diesem Gerät gespeichert. Daten verlassen das Gerät nur, wenn Sie eine Datei aktiv teilen oder exportieren.")
                            .font(.brand(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                .card()
            }
            .padding()
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("Dashboard")
    }

    private var companyHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.brand(.title2))
                .foregroundStyle(Theme.sonneText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Firmenangaben fehlen")
                    .font(.brand(.headline))
                Text("Erfassen Sie Firmenname, Adresse und MWST-Nummer. Sie erscheinen im Kopf jeder Offerte.")
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                Button("Zu den Einstellungen") { router.section = .settings }
                    .buttonStyle(.secondaryAction)
            }
        }
        .card()
    }
}

struct QuickAction: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var prominent = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.brand(.title2))
                .frame(width: 44, height: 44)
                .background(prominent ? Color.white.opacity(0.18) : Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.brand(.headline))
                Text(subtitle).font(.brand(.caption)).opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(prominent ? Theme.gruenSolid : Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

struct RecentProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: project.objectType.systemImage)
                    .foregroundStyle(Theme.gruen)
                    .accessibilityHidden(true)
                StatusBadge(status: project.status)
                Spacer()
                if project.isDemo {
                    Text("Demo").font(.brand(.caption2).weight(.semibold)).foregroundStyle(Theme.grau)
                }
            }
            Text(project.displayTitle)
                .font(.brand(.headline))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(project.customerName)
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)
            HStack {
                Label("\(project.totalCameras) Kameras", systemImage: "video")
                Spacer()
                if let offer = project.latestOffer {
                    Text(Format.chf(offer.recommendedTotal)).monospacedDigit()
                }
            }
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
        }
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Projekt öffnen")
    }
}
