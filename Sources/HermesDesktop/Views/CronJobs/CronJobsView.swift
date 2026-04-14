import SwiftUI

struct CronJobsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var filterMode: CronFilterMode = .all
    @State private var jobToDelete: CronJob?
    @State private var showDeleteConfirmation = false

    enum CronFilterMode: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case paused = "Paused"
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 18) {
                HermesPageHeader(
                    title: "Cron Jobs",
                    subtitle: "Browse and control active Hermes jobs discovered on the active host."
                ) {
                    HermesRefreshButton(isRefreshing: appState.isRefreshingCronJobs) {
                        Task { await appState.refreshCronJobs() }
                    }
                    .disabled(appState.isLoadingCronJobs)
                }

                filterBar
                jobsContent
            }
            .frame(minWidth: 300, idealWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            CronJobDetailView(
                job: selectedJob,
                operationInFlight: operationInFlight(for: selectedJob),
                onRunNow: {
                    guard let selectedJob else { return }
                    Task { await appState.runCronJobNow(selectedJob) }
                },
                onTogglePause: {
                    guard let selectedJob else { return }
                    Task {
                        if selectedJob.isPaused {
                            await appState.resumeCronJob(selectedJob)
                        } else {
                            await appState.pauseCronJob(selectedJob)
                        }
                    }
                },
                onDelete: {
                    guard let selectedJob else { return }
                    jobToDelete = selectedJob
                    showDeleteConfirmation = true
                }
            )
            .frame(minWidth: 440, idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: appState.activeConnectionID) {
            if appState.cronJobs.isEmpty {
                await appState.loadCronJobs()
            }
        }
        .alert("Remove cron job?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                guard let jobToDelete else { return }
                Task { await appState.deleteCronJob(jobToDelete) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let jobToDelete {
                Text("“\(jobToDelete.resolvedName)” will be removed from the remote Hermes scheduler. This cannot be undone.")
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Filter", selection: $filterMode) {
                ForEach(CronFilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer(minLength: 12)

            HermesExpandableSearchField(
                text: $searchText,
                prompt: "Search jobs"
            )
        }
    }

    @ViewBuilder
    private var jobsContent: some View {
        if appState.isLoadingCronJobs && appState.cronJobs.isEmpty {
            HermesSurfacePanel {
                HermesLoadingState(
                    label: "Loading cron jobs…",
                    minHeight: 300
                )
            }
        } else if let error = appState.cronJobsError, appState.cronJobs.isEmpty {
            HermesSurfacePanel {
                ContentUnavailableView(
                    "Unable to load cron jobs",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        } else if appState.cronJobs.isEmpty {
            HermesSurfacePanel {
                ContentUnavailableView(
                    "No cron jobs found",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No saved Hermes cron jobs were discovered under ~/.hermes/cron/jobs.json on this SSH target.")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        } else {
            HermesSurfacePanel(
                title: panelTitle,
                subtitle: "Select a job to inspect its schedule, prompt payload and recent activity."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = appState.cronJobsError {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if filteredJobs.isEmpty {
                        ContentUnavailableView(
                            "No matching cron jobs",
                            systemImage: "magnifyingglass",
                            description: Text("Try searching by job name, schedule, skill, model or prompt text.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(filteredJobs) { job in
                                    CronJobCardRow(
                                        job: job,
                                        isSelected: appState.selectedCronJobID == job.id
                                    ) {
                                        appState.selectedCronJobID = job.id
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if appState.isLoadingCronJobs && !appState.isRefreshingCronJobs && !appState.cronJobs.isEmpty {
                    HermesLoadingOverlay()
                        .padding(18)
                }
            }
        }
    }

    private var filteredJobs: [CronJob] {
        appState.cronJobs.filter { job in
            switch filterMode {
            case .all:
                break
            case .active:
                guard job.isActive else { return false }
            case .paused:
                guard job.isPaused else { return false }
            }

            return job.matchesSearch(searchText)
        }
    }

    private var panelTitle: String {
        let total = appState.cronJobs.count
        let filtered = filteredJobs.count
        let isFiltering = filterMode != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isFiltering {
            return "Cron Jobs (\(filtered) of \(total))"
        }

        return "Cron Jobs (\(total))"
    }

    private var selectedJob: CronJob? {
        guard let selectedCronJobID = appState.selectedCronJobID else { return nil }
        return filteredJobs.first(where: { $0.id == selectedCronJobID })
    }

    private func operationInFlight(for job: CronJob?) -> Bool {
        guard let job else { return false }
        return appState.isOperatingOnCronJob && appState.operatingCronJobID == job.id
    }
}

private struct CronJobCardRow: View {
    let job: CronJob
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(job.resolvedName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(job.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 8) {
                        CronStatusBadge(job: job)

                        if let model = job.displayModel {
                            HermesBadge(text: model, tint: .orange)
                        }
                    }
                }

                Text(job.previewPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        CronMetaLabel(text: job.resolvedScheduleDisplay)

                        if let nextRunAt = job.nextRunAt {
                            CronMetaLabel(
                                text: "Next \(DateFormatters.relativeFormatter().localizedString(for: nextRunAt, relativeTo: .now))"
                            )
                        } else if let lastRunAt = job.lastRunAt {
                            CronMetaLabel(
                                text: "Last \(DateFormatters.relativeFormatter().localizedString(for: lastRunAt, relativeTo: .now))"
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        CronMetaLabel(text: job.resolvedScheduleDisplay)

                        if let nextRunAt = job.nextRunAt {
                            CronMetaLabel(
                                text: "Next \(DateFormatters.relativeFormatter().localizedString(for: nextRunAt, relativeTo: .now))"
                            )
                        } else if let lastRunAt = job.lastRunAt {
                            CronMetaLabel(
                                text: "Last \(DateFormatters.relativeFormatter().localizedString(for: lastRunAt, relativeTo: .now))"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.12 : 0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CronJobDetailView: View {
    let job: CronJob?
    let operationInFlight: Bool
    let onRunNow: () -> Void
    let onTogglePause: () -> Void
    let onDelete: () -> Void

    private let metadataColumns = [
        GridItem(.adaptive(minimum: 180), alignment: .topLeading)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let job {
                    headerPanel(job)

                    if let lastError = job.lastError {
                        HermesSurfacePanel(
                            title: "Last Error",
                            subtitle: "Most recent execution failure reported by Hermes."
                        ) {
                            Text(lastError)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }

                    metadataPanel(job)

                    if !job.skills.isEmpty {
                        HermesSurfacePanel(
                            title: "Skills",
                            subtitle: "Skills attached to this cron job payload."
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(job.skills, id: \.self) { skill in
                                        HermesBadge(
                                            text: skill,
                                            tint: .accentColor,
                                            isMonospaced: true
                                        )
                                    }
                                }
                            }
                        }
                    }

                    HermesSurfacePanel(
                        title: "Prompt",
                        subtitle: "Payload Hermes will run for this scheduled job."
                    ) {
                        HermesInsetSurface {
                            Text(job.trimmedPrompt ?? "No prompt payload saved for this job.")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                } else {
                    HermesSurfacePanel {
                        ContentUnavailableView(
                            "Select a cron job",
                            systemImage: "calendar.badge.clock",
                            description: Text("Choose a Hermes cron job from the active host to inspect its schedule and control it.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
    }

    private func headerPanel(_ job: CronJob) -> some View {
        HermesSurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(job.resolvedName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(job.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 8) {
                        CronStatusBadge(job: job)

                        if let model = job.displayModel {
                            HermesBadge(text: model, tint: .orange)
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button("Run Now", action: onRunNow)
                            .buttonStyle(.borderedProminent)
                            .disabled(operationInFlight)

                        Button(job.isPaused ? "Resume" : "Pause", action: onTogglePause)
                            .buttonStyle(.bordered)
                            .disabled(operationInFlight)

                        Button("Remove", role: .destructive, action: onDelete)
                            .buttonStyle(.bordered)
                            .disabled(operationInFlight)

                        if operationInFlight {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Button("Run Now", action: onRunNow)
                            .buttonStyle(.borderedProminent)
                            .disabled(operationInFlight)

                        Button(job.isPaused ? "Resume" : "Pause", action: onTogglePause)
                            .buttonStyle(.bordered)
                            .disabled(operationInFlight)

                        Button("Remove", role: .destructive, action: onDelete)
                            .buttonStyle(.bordered)
                            .disabled(operationInFlight)

                        if operationInFlight {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func metadataPanel(_ job: CronJob) -> some View {
        HermesSurfacePanel(
            title: "Details",
            subtitle: "Schedule metadata and recent execution markers reported by Hermes."
        ) {
            LazyVGrid(columns: metadataColumns, alignment: .leading, spacing: 14) {
                HermesLabeledValue(
                    label: "Schedule",
                    value: job.resolvedScheduleDisplay,
                    emphasizeValue: true
                )

                if let timezone = job.schedule?.timezone {
                    HermesLabeledValue(
                        label: "Timezone",
                        value: timezone,
                        isMonospaced: true
                    )
                }

                if job.nextRunAt != nil || job.lastRunAt != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        if let nextRunAt = job.nextRunAt {
                            HermesLabeledValue(
                                label: "Next run",
                                value: DateFormatters.shortDateTimeFormatter().string(from: nextRunAt)
                            )
                        }

                        if let lastRunAt = job.lastRunAt {
                            HermesLabeledValue(
                                label: "Last run",
                                value: DateFormatters.shortDateTimeFormatter().string(from: lastRunAt)
                            )
                        }
                    }
                }

                if let createdAt = job.createdAt {
                    HermesLabeledValue(
                        label: "Created",
                        value: DateFormatters.shortDateTimeFormatter().string(from: createdAt)
                    )
                }

                if let lastStatus = job.lastStatus {
                    HermesLabeledValue(
                        label: "Last status",
                        value: lastStatus
                    )
                }

                if let provider = job.provider {
                    HermesLabeledValue(
                        label: "Provider",
                        value: provider,
                        isMonospaced: true
                    )
                }

                if let deliveryTarget = job.deliveryTarget {
                    HermesLabeledValue(
                        label: "Delivery",
                        value: deliveryTarget
                    )
                }

                if let remaining = job.recurrence?.remaining {
                    HermesLabeledValue(
                        label: "Remaining runs",
                        value: String(remaining),
                        isMonospaced: true
                    )
                } else if let times = job.recurrence?.times {
                    HermesLabeledValue(
                        label: "Planned runs",
                        value: String(times),
                        isMonospaced: true
                    )
                }

                if let origin = job.origin?.label ?? job.origin?.source ?? job.origin?.kind {
                    HermesLabeledValue(
                        label: "Origin",
                        value: origin,
                        isMonospaced: job.origin?.source != nil
                    )
                }

                if let lastDeliveryError = job.lastDeliveryError {
                    HermesLabeledValue(
                        label: "Delivery error",
                        value: lastDeliveryError
                    )
                }
            }
        }
    }
}

private struct CronStatusBadge: View {
    let job: CronJob

    var body: some View {
        HermesBadge(text: job.displayState, tint: tint)
    }

    private var tint: Color {
        if job.isRunning {
            return .blue
        }
        if job.isPaused {
            return .orange
        }

        switch job.state.lowercased() {
        case "failed", "error":
            return .red
        default:
            return .green
        }
    }
}

private struct CronMetaLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
