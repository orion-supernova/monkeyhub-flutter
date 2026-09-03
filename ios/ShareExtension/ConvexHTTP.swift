import Foundation

/// Just enough Convex to send one message, over `URLSession`.
///
/// The app talks to Convex over a WebSocket through `convex_flutter`, which is
/// a Rust FFI plugin bound to a Flutter engine. An app extension has neither,
/// and giving it one would mean booting a second engine inside a process with a
/// fraction of the app's memory budget.
///
/// It does not need one. Convex serves an HTTP API alongside the socket
/// (`POST /api/mutation`, `POST /api/query`) with the same function paths and
/// the same argument shapes, so sending is three ordinary HTTP calls.
///
/// ### The token is injected here, once
///
/// `backend/convex/functions.ts` wraps every authenticated function with a
/// required `sessionToken` argument, and the Dart client answers that in one
/// place — `ConvexBackend._withToken` — rather than at its hundred call sites.
/// [mutation] does the same for this side, for the same reason: a second
/// caller that forgets is a call that fails validation outright, and the
/// failure reads as "the share sheet cannot send" rather than as an auth
/// problem.
///
/// This is what that omission actually looked like, from a sheet that had
/// composed perfectly:
///
///     ArgumentValidationError: Object is missing the required field
///     `sessionToken`.
///
/// `share_contract_test.dart` pins the argument's name against
/// `SessionGuard.identityArg`, because the two halves are spelled in different
/// languages and nothing else makes them agree.
enum ConvexHTTP {

    enum Failure: Error {
        /// No network, DNS failure, timeout.
        case transport(Error)
        /// Reached Convex, which refused. Carries what it said.
        case server(String)
        /// Reached Convex, which answered something this code cannot read.
        case malformed
    }

    /// Longest any single call may take.
    ///
    /// An extension is killed by the system on its own schedule and the user is
    /// staring at a spinner over the app they were in, so this is deliberately
    /// tighter than the app's own patience — a send that has not landed in
    /// 30 seconds is better reported than waited on.
    private static let timeout: TimeInterval = 30

    private static var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    // MARK: - Mutations

    /// The argument the session token travels in.
    ///
    /// Mirrors `SessionGuard.identityArg` in Dart, and deliberately not
    /// `token`: several functions already have an argument by that name
    /// carrying a PUSH token. See the note in `session_guard.dart`.
    static let identityArg = "sessionToken"

    /// Runs a Convex mutation and returns its `value`.
    ///
    /// [sessionToken] is added to every call rather than left to the caller —
    /// see the note on this type.
    static func mutation(
        deploymentUrl: String,
        sessionToken: String,
        path: String,
        args: [String: Any],
        completion: @escaping (Result<Any?, Failure>) -> Void
    ) {
        guard let url = URL(string: deploymentUrl.trimmedTrailingSlash + "/api/mutation") else {
            completion(.failure(.malformed))
            return
        }
        var args = args
        args[identityArg] = sessionToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // `format: json` asks Convex for plain JSON rather than its own value
        // encoding. Everything this file sends and reads is strings and
        // numbers, so there is nothing the plain form cannot carry.
        let body: [String: Any] = ["path": path, "args": args, "format": "json"]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(.malformed))
            return
        }
        request.httpBody = data

        session.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(.transport(error)))
                return
            }
            guard
                let data,
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else {
                completion(.failure(.malformed))
                return
            }
            // Convex answers 200 with `{"status": "error", ...}` for a function
            // that threw, so the HTTP status is not the thing to branch on.
            if (json["status"] as? String) == "error" {
                let message = (json["errorMessage"] as? String) ?? "unknown error"
                completion(.failure(.server(message)))
                return
            }
            completion(.success(json["value"]))
        }.resume()
    }

    // MARK: - File upload

    /// Uploads [data] to Convex storage and returns its storage id.
    ///
    /// The same two steps `UploadService.uploadFile` takes in Dart: ask for a
    /// short-lived upload URL, then POST the bytes at it. Kept in that order and
    /// with those names on purpose — `share_contract_test.dart` reads both this
    /// file and the Dart one and fails if they drift.
    static func upload(
        deploymentUrl: String,
        sessionToken: String,
        data: Data,
        contentType: String,
        completion: @escaping (Result<String, Failure>) -> Void
    ) {
        mutation(
            deploymentUrl: deploymentUrl,
            sessionToken: sessionToken,
            // Authenticated like everything else — `functions.ts` calls this
            // one out by name as the shape that takes nothing BUT its identity.
            path: "files:generateUploadUrl",
            args: [:]
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let value):
                guard
                    let raw = value as? String,
                    let url = URL(string: raw)
                else {
                    completion(.failure(.malformed))
                    return
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
                // `uploadTask(with:from:)` rather than `httpBody`: it streams
                // from a temporary file instead of holding a second copy of the
                // bytes in memory, which for a 20 MB video inside an extension's
                // budget is the difference between sending and being killed.
                session.uploadTask(with: request, from: data) { data, _, error in
                    if let error {
                        completion(.failure(.transport(error)))
                        return
                    }
                    guard
                        let data,
                        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                        let storageId = json["storageId"] as? String
                    else {
                        completion(.failure(.malformed))
                        return
                    }
                    completion(.success(storageId))
                }.resume()
            }
        }
    }
}

private extension String {
    /// Convex deployment URLs are written with and without a trailing slash in
    /// different places; joining naively produces `//api/mutation`, which the
    /// backend 404s.
    var trimmedTrailingSlash: String {
        var out = trimmingCharacters(in: .whitespacesAndNewlines)
        while out.hasSuffix("/") { out.removeLast() }
        return out
    }
}
