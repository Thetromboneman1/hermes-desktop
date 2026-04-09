import Foundation

final class FileEditorService: @unchecked Sendable {
    private let sshTransport: SSHTransport

    init(sshTransport: SSHTransport) {
        self.sshTransport = sshTransport
    }

    func read(file: RemoteTrackedFile, connection: ConnectionProfile) async throws -> String {
        let script = try RemotePythonScript.wrap(
            FileRequest(path: file.remoteTildePath),
            body: """
            import json
            import os
            import pathlib
            import sys

            def fail(message):
                print(json.dumps({
                    "ok": False,
                    "error": message,
                }, ensure_ascii=False))
                sys.exit(1)

            try:
                target = pathlib.Path(os.path.expanduser(payload["path"]))
                if not target.exists():
                    fail(f"{payload['path']} does not exist on the remote host.")
                if not target.is_file():
                    fail(f"{payload['path']} is not a regular file.")

                content = target.read_text(encoding="utf-8")
                print(json.dumps({
                    "ok": True,
                    "content": content,
                }, ensure_ascii=False))
            except UnicodeDecodeError:
                fail(f"{payload['path']} is not valid UTF-8.")
            except PermissionError:
                fail(f"Permission denied while reading {payload['path']}.")
            except Exception as exc:
                fail(f"Unable to read {payload['path']}: {exc}")
            """
        )

        let response = try await sshTransport.executeJSON(
            on: connection,
            pythonScript: script,
            responseType: FileReadResponse.self
        )

        return response.content
    }

    func write(file: RemoteTrackedFile, content: String, connection: ConnectionProfile) async throws {
        let script = try RemotePythonScript.wrap(
            FileWriteRequest(path: file.remoteTildePath, content: content, atomic: true),
            body: """
            import json
            import os
            import pathlib
            import sys
            import tempfile

            def fail(message):
                print(json.dumps({
                    "ok": False,
                    "error": message,
                }, ensure_ascii=False))
                sys.exit(1)

            temp_name = None
            directory_fd = None

            try:
                target = pathlib.Path(os.path.expanduser(payload["path"]))
                target.parent.mkdir(parents=True, exist_ok=True)

                fd, temp_name = tempfile.mkstemp(
                    dir=str(target.parent),
                    prefix=f".{target.name}.",
                    suffix=".tmp",
                )

                with os.fdopen(fd, "w", encoding="utf-8") as handle:
                    handle.write(payload["content"])
                    handle.flush()
                    os.fsync(handle.fileno())

                if target.exists():
                    os.chmod(temp_name, target.stat().st_mode)

                os.replace(temp_name, target)

                directory_fd = os.open(target.parent, os.O_RDONLY)
                os.fsync(directory_fd)

                print(json.dumps({
                    "ok": True,
                    "path": payload["path"],
                }, ensure_ascii=False))
            except PermissionError:
                fail(f"Permission denied while writing {payload['path']}.")
            except Exception as exc:
                fail(f"Unable to write {payload['path']}: {exc}")
            finally:
                if directory_fd is not None:
                    os.close(directory_fd)
                if temp_name and os.path.exists(temp_name):
                    os.unlink(temp_name)
            """
        )

        _ = try await sshTransport.executeJSON(
            on: connection,
            pythonScript: script,
            responseType: FileWriteResponse.self
        )
    }
}

private struct FileRequest: Encodable {
    let path: String
}

private struct FileWriteRequest: Encodable {
    let path: String
    let content: String
    let atomic: Bool
}

private struct FileReadResponse: Decodable {
    let ok: Bool
    let content: String
}

private struct FileWriteResponse: Decodable {
    let ok: Bool
    let path: String
}
