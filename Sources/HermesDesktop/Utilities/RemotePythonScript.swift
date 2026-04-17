import Foundation

enum RemotePythonScript {
    static func wrap<Payload: Encodable>(_ payload: Payload, body: String) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let encodedPayload = data.base64EncodedString()

        return """
        import base64
        import json
        import pathlib
        import sys

        payload = json.loads(base64.b64decode("\(encodedPayload)").decode("utf-8"))

        \(sharedHelpers)

        \(body)
        """
    }

    private static let sharedHelpers = """
    def fail(message):
        print(json.dumps({
            "ok": False,
            "error": message,
        }, ensure_ascii=False))
        sys.exit(1)

    def stringify(value):
        if value is None:
            return None
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return str(value)

    def normalize_text(value):
        text = stringify(value)
        if text is None:
            return None
        text = text.strip()
        return text or None

    def choose_table(tables, needle):
        lowered = needle.lower()
        for name in tables:
            if name.lower() == lowered:
                return name
        for name in tables:
            if lowered in name.lower():
                return name
        return None

    def choose_column(columns, choices):
        lowered = {column.lower(): column for column in columns}
        for choice in choices:
            if choice.lower() in lowered:
                return lowered[choice.lower()]
        for choice in choices:
            for column in columns:
                if choice.lower() in column.lower():
                    return column
        return None

    def quote_ident(value):
        return '"' + str(value).replace('"', '""') + '"'

    def quote_text(value):
        return "'" + str(value).replace("'", "''") + "'"

    def expand_remote_path(value, home=None):
        if home is None:
            home = pathlib.Path.home()

        normalized = normalize_text(value)
        if normalized is None:
            return None
        if normalized == "~":
            return home
        if normalized.startswith("~/"):
            return home / normalized[2:]
        return pathlib.Path(normalized)

    def resolved_hermes_home(request=None):
        request_data = payload if request is None else request
        home = pathlib.Path.home()
        expanded = expand_remote_path(request_data.get("hermes_home"), home)
        if expanded is not None:
            return expanded
        return home / ".hermes"

    def tilde(path, home=None):
        if home is None:
            home = pathlib.Path.home()
        try:
            relative = path.relative_to(home)
            return "~/" + relative.as_posix() if relative.as_posix() != "." else "~"
        except ValueError:
            return path.as_posix()

    def iter_session_store_candidates(hermes_home, home=None, hinted_path=None):
        if home is None:
            home = pathlib.Path.home()

        seen = set()

        def emit(candidate):
            if candidate is None:
                return None
            resolved = str(candidate)
            if resolved in seen or not candidate.is_file():
                return None
            seen.add(resolved)
            return candidate

        hinted_candidate = emit(expand_remote_path(hinted_path, home))
        if hinted_candidate is not None:
            yield hinted_candidate

        preferred = [
            hermes_home / "state.db",
            hermes_home / "state.sqlite",
            hermes_home / "state.sqlite3",
            hermes_home / "store.db",
            hermes_home / "store.sqlite",
            hermes_home / "store.sqlite3",
        ]

        for candidate in preferred:
            candidate = emit(candidate)
            if candidate is not None:
                yield candidate

        for candidate in sorted(
            [
                item
                for pattern in ("*.db", "*.sqlite", "*.sqlite3")
                for item in hermes_home.glob(pattern)
                if item.is_file()
            ],
            key=lambda item: item.stat().st_mtime,
            reverse=True,
        ):
            candidate = emit(candidate)
            if candidate is not None:
                yield candidate

        sessions_dir = hermes_home / "sessions"
        if sessions_dir.exists():
            for candidate in sorted(
                [
                    item
                    for pattern in ("*.db", "*.sqlite", "*.sqlite3")
                    for item in sessions_dir.rglob(pattern)
                    if item.is_file()
                ],
                key=lambda item: item.stat().st_mtime,
                reverse=True,
            ):
                candidate = emit(candidate)
                if candidate is not None:
                    yield candidate
    """
}
