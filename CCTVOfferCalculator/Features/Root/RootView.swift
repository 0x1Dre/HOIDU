import SwiftUI
import SwiftData

struct RootView: View {
    let storageError: String?

    @Environment(AppRouter.self) private var router
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showStorageError = false

    var body: some View {
        @Bindable var bindableRouter = router
        Group {
            if horizontalSizeClass == .compact {
                TabView(selection: $bindableRouter.section) {
                    ForEach(AppSection.allCases) { section in
                        SectionRoot(section: section)
                            .tabItem { Label(section.title, systemImage: section.systemImage) }
                            .tag(section)
                    }
                }
            } else {
                NavigationSplitView {
                    List(selection: Binding<AppSection?>(
                        get: { router.section },
                        set: { if let value = $0 { router.section = value } }
                    )) {
                        ForEach(AppSection.allCases) { section in
                            NavigationLink(value: section) {
                                Label(section.title, systemImage: section.systemImage)
                                    .font(.brand(.headline))
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .navigationTitle("Ostsicht")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            OstsichtLogo(layout: .horizontal)
                                .frame(height: 32)
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        Label("Offline – Daten bleiben auf dem Gerät", systemImage: "lock.shield")
                            .font(.brand(.footnote))
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } detail: {
                    SectionRoot(section: router.section)
                        .id(router.section)
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .task {
            PersistenceController.seedIfNeeded(context: modelContext, settings: settings)
            showStorageError = storageError != nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                router.persistDraft()
            }
        }
        .alert("Speicherproblem", isPresented: $showStorageError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storageError ?? "")
        }
    }
}

/// Inhalt eines Navigationsbereichs mit eigenem Navigationsstapel.
struct SectionRoot: View {
    let section: AppSection
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var bindableRouter = router
        switch section {
        case .dashboard:
            NavigationStack { DashboardView() }
        case .projects:
            NavigationStack(path: $bindableRouter.projectPath) {
                ProjectListView()
                    .navigationDestination(for: ProjectRoute.self) { route in
                        ProjectDetailLoader(id: route.id)
                    }
            }
        case .newProject:
            NavigationStack { NewProjectView() }
        case .priceLists:
            NavigationStack { PriceListsView() }
        case .manufacturers:
            NavigationStack { ManufacturerProfilesView() }
        case .settings:
            NavigationStack { SettingsView() }
        }
    }
}
