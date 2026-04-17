import Foundation

final class RemoteHermesService: @unchecked Sendable {
    private let sshTransport: SSHTransport

    init(sshTransport: SSHTransport) {
        self.sshTransport = sshTransport
    }

    func discover(connection: ConnectionProfile) async throws -> RemoteDiscovery {
        let script = try RemotePythonScript.wrap(
            RemoteDiscoveryRequest(
                hermesHome: connection.remoteHermesHomePath,
                profileName: connection.resolvedHermesProfileName
            ),
            body: discoveryScript
        )

        return try await sshTransport.executeJSON(
            on: connection,
            pythonScript: script,
            responseType: RemoteDiscovery.self
        )
    }

    private var discoveryScript: String {
        """
        import json
        import pathlib
        import sqlite3

        def discover_session_store(hermes_home: pathlib.Path):
            if not hermes_home.exists():
                return None

            for candidate in iter_session_store_candidates(hermes_home):
                try:
                    conn = sqlite3.connect(f"file:{candidate}?mode=ro", uri=True)
                    cursor = conn.execute(
                        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
                    )
                    tables = [row[0] for row in cursor.fetchall()]
                    session_table = choose_table(tables, "sessions")
                    message_table = choose_table(tables, "messages")
                    if session_table and message_table:
                        conn.close()
                        return {
                            "kind": "sqlite",
                            "path": tilde(candidate, home),
                            "session_table": session_table,
                            "message_table": message_table,
                        }
                    conn.close()
                except Exception:
                    continue

            return None

        try:
            home = pathlib.Path.home()
            default_hermes_home = home / ".hermes"
            hermes_home = expand_remote_path(payload.get("hermes_home"), home) or default_hermes_home
            user_path = hermes_home / "memories" / "USER.md"
            memory_path = hermes_home / "memories" / "MEMORY.md"
            soul_path = hermes_home / "SOUL.md"
            sessions_dir = hermes_home / "sessions"
            cron_jobs_path = hermes_home / "cron" / "jobs.json"
            profiles_dir = default_hermes_home / "profiles"

            available_profiles = [{
                "name": "default",
                "path": tilde(default_hermes_home, home),
                "is_default": True,
                "exists": default_hermes_home.exists(),
            }]

            if profiles_dir.exists():
                for item in sorted(
                    [entry for entry in profiles_dir.iterdir() if entry.is_dir()],
                    key=lambda entry: entry.name.lower(),
                ):
                    available_profiles.append({
                        "name": item.name,
                        "path": tilde(item, home),
                        "is_default": False,
                        "exists": True,
                    })

            active_profile_name = payload.get("profile_name")
            if hermes_home == default_hermes_home:
                active_profile_name = "default"
            elif not active_profile_name:
                active_profile_name = hermes_home.name

            result = {
                "ok": True,
                "remote_home": tilde(home, home),
                "hermes_home": tilde(hermes_home, home),
                "active_profile": {
                    "name": active_profile_name,
                    "path": tilde(hermes_home, home),
                    "is_default": hermes_home == default_hermes_home,
                    "exists": hermes_home.exists(),
                },
                "available_profiles": available_profiles,
                "paths": {
                    "user": tilde(user_path, home),
                    "memory": tilde(memory_path, home),
                    "soul": tilde(soul_path, home),
                    "sessions_dir": tilde(sessions_dir, home),
                    "cron_jobs": tilde(cron_jobs_path, home),
                },
                "exists": {
                    "user": user_path.exists(),
                    "memory": memory_path.exists(),
                    "soul": soul_path.exists(),
                    "sessions_dir": sessions_dir.exists(),
                    "cron_jobs": cron_jobs_path.exists(),
                },
                "session_store": discover_session_store(hermes_home),
            }

            print(json.dumps(result, ensure_ascii=False))
        except Exception as exc:
            fail(f"Unable to discover the remote Hermes workspace: {exc}")
        """
    }
}

private struct RemoteDiscoveryRequest: Encodable {
    let hermesHome: String
    let profileName: String

    enum CodingKeys: String, CodingKey {
        case hermesHome = "hermes_home"
        case profileName = "profile_name"
    }
}
