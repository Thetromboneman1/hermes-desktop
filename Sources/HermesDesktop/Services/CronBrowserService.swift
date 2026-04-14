import Foundation

final class CronBrowserService: @unchecked Sendable {
    private let sshTransport: SSHTransport

    init(sshTransport: SSHTransport) {
        self.sshTransport = sshTransport
    }

    func listJobs(connection: ConnectionProfile) async throws -> [CronJob] {
        let script = try RemotePythonScript.wrap(EmptyCronRequest(), body: listJobsBody)
        let result = try await sshTransport.execute(
            on: connection,
            remoteCommand: "python3 -",
            standardInput: Data(script.utf8),
            allocateTTY: false
        )

        try sshTransport.validateSuccessfulExit(result, for: connection)

        guard let data = result.stdout.data(using: .utf8) else {
            throw SSHTransportError.invalidResponse("Remote cron output was not valid UTF-8.")
        }

        do {
            return try makeDecoder().decode(CronJobListResponse.self, from: data).jobs
        } catch {
            throw SSHTransportError.invalidResponse(
                "Failed to decode remote cron metadata: \(error.localizedDescription)\n\n\(result.stdout)"
            )
        }
    }

    func pauseJob(connection: ConnectionProfile, jobID: String) async throws {
        try await performCommand(connection: connection, jobID: jobID, command: .pause)
    }

    func resumeJob(connection: ConnectionProfile, jobID: String) async throws {
        try await performCommand(connection: connection, jobID: jobID, command: .resume)
    }

    func removeJob(connection: ConnectionProfile, jobID: String) async throws {
        try await performCommand(connection: connection, jobID: jobID, command: .remove)
    }

    func runJobNow(connection: ConnectionProfile, jobID: String) async throws {
        try await performCommand(connection: connection, jobID: jobID, command: .run)
    }

    private func performCommand(
        connection: ConnectionProfile,
        jobID: String,
        command: CronCommand
    ) async throws {
        let script = try RemotePythonScript.wrap(
            CronCommandRequest(jobID: jobID, command: command.rawValue),
            body: commandBody
        )

        _ = try await sshTransport.executeJSON(
            on: connection,
            pythonScript: script,
            responseType: CronCommandResponse.self
        )
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.fractionalSecondsFormatter().date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }

    private var listJobsBody: String {
        """
        import json
        import pathlib
        import sys
        from datetime import datetime, timezone

        def fail(message):
            print(json.dumps({
                "ok": False,
                "error": message,
            }, ensure_ascii=False))
            sys.exit(1)

        def normalize_text(value):
            if value is None:
                return None
            if isinstance(value, bytes):
                value = value.decode("utf-8", errors="replace")
            value = str(value).strip()
            return value or None

        def normalize_bool(value):
            if isinstance(value, bool):
                return value
            if value is None:
                return None

            lowered = str(value).strip().lower()
            if lowered in {"1", "true", "yes", "on"}:
                return True
            if lowered in {"0", "false", "no", "off"}:
                return False
            return None

        def normalize_list(value):
            if value is None:
                return []
            if isinstance(value, (list, tuple, set)):
                items = []
                for item in value:
                    normalized = normalize_text(item)
                    if normalized is not None:
                        items.append(normalized)
                return items

            normalized = normalize_text(value)
            return [normalized] if normalized is not None else []

        def first_text(*values):
            for value in values:
                normalized = normalize_text(value)
                if normalized is not None:
                    return normalized
            return None

        def first_int(*values):
            for value in values:
                if value is None:
                    continue
                try:
                    return int(value)
                except Exception:
                    continue
            return None

        def normalize_date(value):
            if value is None:
                return None
            if isinstance(value, (int, float)):
                return datetime.fromtimestamp(float(value), tz=timezone.utc).isoformat()

            text = normalize_text(value)
            if text is None:
                return None

            try:
                return datetime.fromtimestamp(float(text), tz=timezone.utc).isoformat()
            except Exception:
                return text

        def normalize_state(item):
            raw_state = first_text(
                item.get("state"),
                item.get("status"),
                item.get("job_state"),
            )
            if raw_state is not None:
                return raw_state.lower()

            if item.get("paused_at") is not None:
                return "paused"
            if normalize_bool(item.get("running")) is True:
                return "running"
            if normalize_bool(item.get("enabled")) is False:
                return "paused"
            return "scheduled"

        def normalize_schedule(item):
            schedule = item.get("schedule") if isinstance(item.get("schedule"), dict) else {}
            expr = first_text(
                schedule.get("expr"),
                schedule.get("expression"),
                item.get("cron"),
                item.get("schedule_expr"),
            )
            schedule_display = first_text(
                item.get("schedule_display"),
                item.get("scheduleDisplay"),
                schedule.get("display"),
                schedule.get("summary"),
                expr,
            ) or "Custom schedule"

            normalized_schedule = {
                "kind": first_text(schedule.get("kind"), item.get("schedule_kind")),
                "expr": expr,
                "timezone": first_text(schedule.get("timezone"), schedule.get("tz"), item.get("timezone")),
            }

            if normalized_schedule["kind"] is None and normalized_schedule["expr"] is None and normalized_schedule["timezone"] is None:
                normalized_schedule = None

            return normalized_schedule, schedule_display

        def normalize_recurrence(item):
            recurrence = item.get("recurrence")
            if not isinstance(recurrence, dict):
                recurrence = item.get("repeat")
            if not isinstance(recurrence, dict):
                return None

            times = first_int(recurrence.get("times"))
            remaining = first_int(recurrence.get("remaining"), recurrence.get("remaining_runs"))

            if times is None and remaining is None:
                return None

            return {
                "times": times,
                "remaining": remaining,
            }

        def normalize_origin(item):
            origin = item.get("origin")
            if not isinstance(origin, dict):
                return None

            normalized = {
                "kind": first_text(origin.get("kind"), origin.get("type")),
                "source": first_text(origin.get("source"), origin.get("path")),
                "label": first_text(origin.get("label"), origin.get("name")),
            }

            if normalized["kind"] is None and normalized["source"] is None and normalized["label"] is None:
                return None

            return normalized

        def delivery_target(item, payload):
            delivery = item.get("delivery")
            if isinstance(delivery, dict):
                return first_text(delivery.get("target"), delivery.get("destination"), delivery.get("mode"))

            return first_text(
                item.get("deliver"),
                item.get("delivery_target"),
                delivery,
                payload.get("deliver") if isinstance(payload, dict) else None,
            )

        def normalize_job(item):
            if not isinstance(item, dict):
                return None

            job_id = first_text(item.get("id"), item.get("job_id"), item.get("slug"))
            if job_id is None:
                return None

            payload_data = item.get("payload")
            payload = payload_data if isinstance(payload_data, dict) else {}
            prompt = first_text(
                item.get("prompt"),
                item.get("message"),
                payload.get("prompt"),
                payload.get("message"),
                payload.get("task"),
            ) or ""

            name = first_text(
                item.get("name"),
                item.get("title"),
                payload.get("name"),
                prompt.splitlines()[0] if prompt else None,
                job_id,
            ) or job_id

            skills = normalize_list(item.get("skills"))
            if not skills:
                skills = normalize_list(payload.get("skills"))

            schedule, schedule_display = normalize_schedule(item)
            state = normalize_state(item)
            enabled = normalize_bool(item.get("enabled"))
            if enabled is None:
                enabled = state != "paused"

            return {
                "id": job_id,
                "name": name,
                "prompt": prompt,
                "skills": skills,
                "model": first_text(item.get("model"), payload.get("model")),
                "provider": first_text(item.get("provider"), item.get("billing_provider"), payload.get("provider")),
                "schedule": schedule,
                "schedule_display": schedule_display,
                "recurrence": normalize_recurrence(item),
                "enabled": enabled,
                "state": state,
                "created_at": normalize_date(item.get("created_at")),
                "next_run_at": normalize_date(item.get("next_run_at")),
                "last_run_at": normalize_date(item.get("last_run_at")),
                "last_status": first_text(item.get("last_status"), item.get("run_status")),
                "last_error": first_text(item.get("last_error"), item.get("error")),
                "delivery_target": delivery_target(item, payload),
                "origin": normalize_origin(item),
                "last_delivery_error": first_text(item.get("last_delivery_error")),
            }

        try:
            jobs_path = pathlib.Path.home() / ".hermes" / "cron" / "jobs.json"
            if not jobs_path.exists():
                print(json.dumps({
                    "ok": True,
                    "jobs": [],
                }, ensure_ascii=False))
                sys.exit(0)

            raw_data = json.loads(jobs_path.read_text(encoding="utf-8"))
            if isinstance(raw_data, dict):
                raw_jobs = raw_data.get("jobs") or raw_data.get("items") or raw_data.get("cron_jobs") or []
            elif isinstance(raw_data, list):
                raw_jobs = raw_data
            else:
                fail(f"Unsupported cron metadata format in {jobs_path}.")

            jobs = []
            for item in raw_jobs:
                normalized = normalize_job(item)
                if normalized is not None:
                    jobs.append(normalized)

            jobs.sort(
                key=lambda item: (
                    item.get("next_run_at") is None,
                    item.get("next_run_at") or "",
                    item.get("name", "").lower(),
                )
            )

            print(json.dumps({
                "ok": True,
                "jobs": jobs,
            }, ensure_ascii=False))
        except Exception as exc:
            fail(f"Unable to read the remote Hermes cron jobs: {exc}")
        """
    }

    private var commandBody: String {
        """
        import json
        import os
        import pathlib
        import shutil
        import subprocess
        import sys

        def fail(message):
            print(json.dumps({
                "ok": False,
                "error": message,
            }, ensure_ascii=False))
            sys.exit(1)

        def find_hermes_binary():
            candidate = shutil.which("hermes")
            if candidate:
                return candidate

            fallback = pathlib.Path.home() / ".local" / "bin" / "hermes"
            if fallback.exists() and os.access(fallback, os.X_OK):
                return str(fallback)

            return None

        job_id = str(payload.get("job_id") or "").strip()
        command = str(payload.get("command") or "").strip()

        if not job_id:
            fail("The cron job ID is required.")
        if not command:
            fail("The cron command is required.")

        hermes_binary = find_hermes_binary()
        if hermes_binary is None:
            fail("Hermes CLI was not found on the active host.")

        try:
            completed = subprocess.run(
                [hermes_binary, "cron", command, job_id],
                capture_output=True,
                text=True,
            )
        except Exception as exc:
            fail(f"Unable to launch Hermes CLI: {exc}")

        if completed.returncode != 0:
            message = (completed.stderr or completed.stdout or f"Hermes cron {command} failed.").strip()
            fail(message)

        print(json.dumps({
            "ok": True,
            "message": (completed.stdout or "").strip() or None,
        }, ensure_ascii=False))
        """
    }
}

private struct EmptyCronRequest: Encodable {}

private struct CronCommandRequest: Encodable {
    let jobID: String
    let command: String

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case command
    }
}

private struct CronCommandResponse: Decodable {
    let ok: Bool
    let message: String?
}

private enum CronCommand: String {
    case pause
    case resume
    case run
    case remove
}
