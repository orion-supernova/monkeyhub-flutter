// AppleSpeechCore: file transcription with Apple's built-in on-device
// recognizer (SpeechAnalyzer + SpeechTranscriber, iOS 26 / macOS 26).
//
// This file must compile WITHOUT Flutter: the plugin glue lives in
// AppleSpeechPlugin.swift, and a scratch CLI compiles this file alone with
// swiftc to exercise it on a real Mac. Everything here returns plain Swift
// values; the glue turns them into channel maps.
//
// Deployment targets are iOS 15 / macOS 12, so every Speech API from OS 26 is
// behind `#available`, and older OSes report unavailable.

import AVFoundation
import CoreMedia
import Foundation
import Speech

/// Error codes, 1:1 with the Dart `AppleSpeechError` enum names.
enum AppleSpeechCode: String {
    case unavailable, unsupportedLocale, assetsFailed, decode,
         permissionDenied, cancelled, failed
}

struct AppleSpeechCoreError: Error, CustomStringConvertible {
    let code: AppleSpeechCode
    let message: String?
    init(_ code: AppleSpeechCode, _ message: String? = nil) {
        self.code = code
        self.message = message
    }
    var description: String { "\(code.rawValue): \(message ?? "")" }
}

struct AppleSpeechWordOut {
    let text: String
    let startMs: Int
    let endMs: Int
    /// 0..1 from the transcriptionConfidence attribute, nil if not reported.
    let confidence: Double?
}

struct AppleSpeechResultOut {
    let text: String
    let locale: String
    let words: [AppleSpeechWordOut]
    /// Character-weighted mean word confidence, nil when there are no words.
    /// Measured on macOS 27: right language ~0.9, wrong language < 0.3.
    let confidence: Double?
    /// "speech" (SpeechTranscriber) or "dictation" (DictationTranscriber).
    let engine: String
    /// True when at least one transcriber run spanned several words, so some
    /// word times were interpolated by character count (diagnostics only).
    let interpolated: Bool
}

final class AppleSpeechCore: @unchecked Sendable {
    static let shared = AppleSpeechCore()

    private let lock = NSLock()
    private var currentTask: Task<AppleSpeechResultOut, Error>?
    /// The live analyzer, held as Any so this stored property needs no
    /// availability annotation.
    private var currentAnalyzer: Any?
    private var cancelRequested = false

    /// Synchronous so it may take the lock from async code.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: Engines

    /// Which Apple module serves a locale. SpeechTranscriber is the new,
    /// better long-form model but covers fewer languages (no Turkish, Swedish
    /// or Arabic as of macOS 27); DictationTranscriber is the keyboard
    /// dictation model, same SpeechAnalyzer pipeline, many more languages.
    enum Engine: String { case speech, dictation }

    @available(iOS 26.0, macOS 26.0, *)
    private struct Catalog {
        let speech: [Locale]
        let dictation: [Locale]
        static func load() async -> Catalog {
            let speech = SpeechTranscriber.isAvailable ? await SpeechTranscriber.supportedLocales : []
            return Catalog(speech: speech, dictation: await DictationTranscriber.supportedLocales)
        }
    }

    // MARK: Availability and locales

    /// OS 26+ and at least one engine usable on this device.
    func isAvailable() async -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            if SpeechTranscriber.isAvailable { return true }
            return !(await DictationTranscriber.supportedLocales.isEmpty)
        }
        return false
    }

    /// Union of both engines, BCP-47, sorted.
    func supportedLocales() async -> [String] {
        if #available(iOS 26.0, macOS 26.0, *) {
            let c = await Catalog.load()
            return Array(Set((c.speech + c.dictation).map(Self.bcp47))).sorted()
        }
        return []
    }

    /// A locale counts as installed when the engine that would serve it has
    /// its model on device.
    func installedLocales() async -> [String] {
        if #available(iOS 26.0, macOS 26.0, *) {
            let c = await Catalog.load()
            let speechTags = Set(c.speech.map(Self.bcp47))
            var out = Set<String>()
            if SpeechTranscriber.isAvailable {
                out.formUnion(await SpeechTranscriber.installedLocales.map(Self.bcp47))
            }
            for l in await DictationTranscriber.installedLocales.map(Self.bcp47)
            where !speechTags.contains(l) {
                out.insert(l)
            }
            return out.sorted()
        }
        return []
    }

    func bestLocale(_ preferred: [String]) async -> String? {
        if #available(iOS 26.0, macOS 26.0, *) {
            let c = await Catalog.load()
            for raw in preferred {
                if let hit = await resolve(raw, catalog: c) { return Self.bcp47(hit.0) }
            }
        }
        return nil
    }

    /// Engine name for a locale ("speech" / "dictation"), nil if unsupported.
    func engine(for raw: String) async -> String? {
        if #available(iOS 26.0, macOS 26.0, *) {
            return await resolve(raw, catalog: await Catalog.load())?.1.rawValue
        }
        return nil
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func resolve(_ raw: String, catalog c: Catalog) async -> (Locale, Engine)? {
        if let l = await pick(raw, from: c.speech, equivalent: SpeechTranscriber.supportedLocale(equivalentTo:)) {
            return (l, .speech)
        }
        if let l = await pick(raw, from: c.dictation, equivalent: DictationTranscriber.supportedLocale(equivalentTo:)) {
            return (l, .dictation)
        }
        return nil
    }

    /// Picks a locale for [raw] (full tag or bare language) from [supported].
    /// 1. exact language+region match ("pt-PT", "en-GB");
    /// 2. for a script-qualified tag, the framework's
    ///    supportedLocale(equivalentTo:) ("zh-Hant" -> zh-TW). It is not used
    ///    for bare codes: on macOS 27 it answers randomly (en -> en-SG one
    ///    call, en-US the next; fr -> fr-CA / fr-CH / fr-FR);
    /// 3. a region we lack: pt -> pt-PT, zh -> nil, others fall through;
    /// 4. same language: device region, then the language's likely region
    ///    (sv -> SE, pt -> BR, en -> US, es -> ES), then the first.
    @available(iOS 26.0, macOS 26.0, *)
    private func pick(_ raw: String, from supported: [Locale],
                      equivalent: (Locale) async -> Locale?) async -> Locale? {
        let tag = raw.replacingOccurrences(of: "_", with: "-")
        let wanted = Locale(identifier: tag)
        // Locale.region / Language.script infer missing subtags (fr -> Latn,
        // and a region from user settings); use only what the tag spells out.
        let explicit = Locale.Language.Components(identifier: tag)
        guard var lang = explicit.languageCode?.identifier.lowercased() else { return nil }
        // Legacy / macro codes the catalogs spell differently.
        lang = ["no": "nb", "iw": "he", "in": "id", "ji": "yi"][lang] ?? lang
        let sameLang = supported.filter { $0.language.languageCode?.identifier == lang }
        if sameLang.isEmpty { return nil }
        let region = explicit.region?.identifier
        let script = explicit.script
        if let region, let exact = sameLang.first(where: { $0.region?.identifier == region }) {
            return exact
        }
        // With no region asked for, equivalentTo picks oddly (en -> en-SG), so
        // only trust it for script-qualified tags (zh-Hant -> zh-TW).
        if script != nil, let eq = await equivalent(wanted),
           eq.language.languageCode?.identifier == lang {
            return eq
        }
        if region != nil {
            // Asked-for region missing. Portuguese outside Brazil follows the
            // European norm; Chinese regions differ in script, so refuse.
            if lang == "pt" { return sameLang.first { $0.region?.identifier == "PT" } }
            if lang == "zh" { return nil }
        }
        if let deviceRegion = Locale.current.region?.identifier,
           let hit = sameLang.first(where: { $0.region?.identifier == deviceRegion }) {
            return hit
        }
        let likely = Locale(identifier: Locale.Language(identifier: lang).maximalIdentifier)
        if let likelyRegion = likely.region?.identifier,
           let hit = sameLang.first(where: { $0.region?.identifier == likelyRegion }) {
            return hit
        }
        return sameLang.sorted { Self.bcp47($0) < Self.bcp47($1) }.first
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func resolveOrThrow(_ raw: String) async throws -> (Locale, Engine) {
        guard let hit = await resolve(raw, catalog: await Catalog.load()) else {
            throw AppleSpeechCoreError(.unsupportedLocale, raw)
        }
        return hit
    }

    // MARK: Assets

    func ensureAssets(_ raw: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        guard await isAvailable() else { throw AppleSpeechCoreError(.unavailable) }
        if #available(iOS 26.0, macOS 26.0, *) {
            let (locale, engine) = try await resolveOrThrow(raw)
            try await install(locale, engine, onProgress: onProgress)
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func install(_ locale: Locale, _ engine: Engine,
                         onProgress: @escaping @Sendable (Double) -> Void) async throws {
        let module = Self.makeModule(locale, engine)
        await reserve(locale)
        let status = await AssetInventory.status(forModules: [module])
        if status == .unsupported {
            throw AppleSpeechCoreError(.unsupportedLocale, Self.bcp47(locale))
        }
        if status == .installed {
            onProgress(1)
            return
        }
        let request: AssetInstallationRequest?
        do {
            request = try await AssetInventory.assetInstallationRequest(supporting: [module])
        } catch {
            throw Self.map(error, fallback: .assetsFailed)
        }
        guard let request else {
            onProgress(1)
            return
        }
        onProgress(0)
        let progress = request.progress
        let watcher = progress.observe(\.fractionCompleted, options: [.new]) { p, _ in
            onProgress(min(max(p.fractionCompleted, 0), 1))
        }
        defer { watcher.invalidate() }
        do {
            try await request.downloadAndInstall()
        } catch {
            throw Self.map(error, fallback: .assetsFailed)
        }
        onProgress(1)
    }

    /// Reserves [locale] so the system keeps its model around. When the
    /// per-app budget (AssetInventory.maximumReservedLocales, 5 on macOS 27)
    /// is full, releases the first other reserved locale. Best effort.
    @available(iOS 26.0, macOS 26.0, *)
    private func reserve(_ locale: Locale) async {
        let tag = Self.bcp47(locale)
        let reserved = await AssetInventory.reservedLocales
        if reserved.contains(where: { Self.bcp47($0) == tag }) { return }
        if reserved.count >= AssetInventory.maximumReservedLocales,
           let victim = reserved.first(where: { Self.bcp47($0) != tag }) {
            await AssetInventory.release(reservedLocale: victim)
        }
        _ = try? await AssetInventory.reserve(locale: locale)
    }

    // MARK: Permission

    /// SpeechAnalyzer runs fully on device and does not consult the classic
    /// speech-recognition permission: verified on macOS 27, it transcribes
    /// with SFSpeechRecognizer.authorizationStatus() == .notDetermined, no
    /// prompt and no usage-description key. So this never prompts.
    func ensurePermission() async -> Bool {
        return await isAvailable()
    }

    // MARK: Transcription

    func transcribe(path: String, locale raw: String,
                    onProgress: @escaping @Sendable (Double) -> Void) async throws -> AppleSpeechResultOut {
        guard await isAvailable() else { throw AppleSpeechCoreError(.unavailable) }
        guard #available(iOS 26.0, macOS 26.0, *) else { throw AppleSpeechCoreError(.unavailable) }
        let task = Task<AppleSpeechResultOut, Error> {
            try await self.run(path: path, raw: raw, onProgress: onProgress)
        }
        locked {
            currentTask?.cancel()
            currentTask = task
            cancelRequested = false
        }
        defer {
            locked {
                if currentTask == task {
                    currentTask = nil
                    currentAnalyzer = nil
                }
            }
        }
        do {
            return try await task.value
        } catch {
            let cancelled = locked { cancelRequested } || task.isCancelled
            if cancelled { throw AppleSpeechCoreError(.cancelled) }
            throw Self.map(error, fallback: .failed)
        }
    }

    func cancel() async {
        let (task, analyzer) = locked { () -> (Task<AppleSpeechResultOut, Error>?, Any?) in
            cancelRequested = true
            return (currentTask, currentAnalyzer)
        }
        task?.cancel()
        if #available(iOS 26.0, macOS 26.0, *), let analyzer = analyzer as? SpeechAnalyzer {
            await analyzer.cancelAndFinishNow()
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func run(path: String, raw: String,
                     onProgress: @escaping @Sendable (Double) -> Void) async throws -> AppleSpeechResultOut {
        let (locale, engine) = try await resolveOrThrow(raw)
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        } catch {
            throw AppleSpeechCoreError(.decode, error.localizedDescription)
        }
        let rate = file.processingFormat.sampleRate
        let durationSec = rate > 0 ? Double(file.length) / rate : 0
        guard durationSec > 0 else { throw AppleSpeechCoreError(.decode, "empty audio") }

        // Models normally come from ensureAssets first; install on demand so
        // a direct call still works (progress for that part is not reported).
        let module = Self.makeModule(locale, engine)
        if await AssetInventory.status(forModules: [module]) != .installed {
            try await install(locale, engine, onProgress: { _ in })
        }
        try Task.checkCancellation()

        let analyzer = SpeechAnalyzer(
            modules: [module],
            options: .init(priority: .userInitiated, modelRetention: .lingering))
        let alreadyCancelled = locked { () -> Bool in
            currentAnalyzer = analyzer
            return cancelRequested
        }
        if alreadyCancelled { throw AppleSpeechCoreError(.cancelled) }

        // Results stream concurrently with analysis: final results only (no
        // volatile option), each a phrase-sized AttributedString. Progress is
        // the end of the latest result over the file duration.
        let report: @Sendable (CMTime) -> Void = { end in
            let s = end.seconds
            if s.isFinite { onProgress(min(max(s / durationSec, 0), 0.99)) }
        }
        let collector: Task<[AttributedString], Error>
        if let t = module as? SpeechTranscriber {
            collector = Task {
                var out: [AttributedString] = []
                for try await r in t.results { out.append(r.text); report(r.range.end) }
                return out
            }
        } else if let d = module as? DictationTranscriber {
            collector = Task {
                var out: [AttributedString] = []
                for try await r in d.results { out.append(r.text); report(r.range.end) }
                return out
            }
        } else {
            throw AppleSpeechCoreError(.failed, "no module")
        }

        let segments: [AttributedString]
        do {
            onProgress(0)
            // analyzeSequence(from: AVAudioFile) reads and converts the file to
            // the analyzer's format itself (AAC m4a at 22.05/44.1 kHz works).
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            segments = try await collector.value
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            if Task.isCancelled { throw AppleSpeechCoreError(.cancelled) }
            throw Self.map(error, fallback: .failed)
        }
        onProgress(1)
        return Self.assemble(segments, locale: Self.bcp47(locale), engine: engine)
    }

    @available(iOS 26.0, macOS 26.0, *)
    static func makeModule(_ locale: Locale, _ engine: Engine) -> any SpeechModule {
        switch engine {
        case .speech:
            // Offline file transcription: final results only, with per-run
            // audio time ranges (the .timeIndexedTranscriptionWithAlternatives
            // preset minus the alternatives we never show).
            return SpeechTranscriber(locale: locale,
                                     transcriptionOptions: [],
                                     reportingOptions: [],
                                     attributeOptions: [.audioTimeRange, .transcriptionConfidence])
        case .dictation:
            // Like .timeIndexedLongDictation, final results only.
            return DictationTranscriber(locale: locale,
                                        contentHints: [],
                                        transcriptionOptions: [.punctuation],
                                        reportingOptions: [],
                                        attributeOptions: [.audioTimeRange, .transcriptionConfidence])
        }
    }

    // MARK: Word assembly

    /// One timed piece of transcript: an AttributedString run.
    struct Token {
        var text: String
        var start: Double?
        var end: Double?
        var confidence: Double? = nil
    }

    @available(iOS 26.0, macOS 26.0, *)
    static func tokens(of text: AttributedString) -> [Token] {
        var out: [Token] = []
        for run in text.runs {
            let piece = String(text[run.range].characters)
            if piece.isEmpty { continue }
            let range = run.audioTimeRange
            out.append(Token(text: piece, start: range?.start.seconds, end: range?.end.seconds,
                             confidence: run.transcriptionConfidence))
        }
        return out
    }

    @available(iOS 26.0, macOS 26.0, *)
    static func assemble(_ segments: [AttributedString], locale: String, engine: Engine) -> AppleSpeechResultOut {
        var all: [Token] = []
        for segment in segments {
            var toks = tokens(of: segment)
            if toks.isEmpty { continue }
            // Consecutive results carry no separator of their own; add a space
            // between them unless either side is a no-space script.
            if let prev = all.last?.text.last, let next = toks[0].text.first,
               !prev.isWhitespace, !next.isWhitespace,
               !isNoSpaceScript(prev), !isNoSpaceScript(next) {
                toks[0].text = " " + toks[0].text
            }
            all.append(contentsOf: toks)
        }
        return buildWords(all, locale: locale, engine: engine)
    }

    /// Splits timed tokens into words. A word is its leading whitespace plus a
    /// run of non-space characters, so concatenating word texts reproduces the
    /// transcript exactly. Tokens that hold several words get their time range
    /// split by character count; tokens that are pieces of one word merge. In
    /// no-space scripts (Han, kana, Thai...) each run is its own word.
    static func buildWords(_ tokens: [Token], locale: String, engine: Engine) -> AppleSpeechResultOut {
        struct Piece {
            var text: String
            var start: Double?
            var end: Double?
            var conf: Double? = nil
            var confWeight: Double = 0
            init(text: String, start: Double?, end: Double?, conf: Double? = nil) {
                self.text = text
                self.start = start
                self.end = end
                if let conf {
                    self.conf = conf
                    self.confWeight = Double(max(text.trimmingCharacters(in: .whitespaces).count, 1))
                }
            }
        }
        var pieces: [Piece] = []
        var interpolated = false

        for tok in tokens {
            let parts = splitKeepingLeadingSpace(tok.text)
            if parts.count <= 1 {
                pieces.append(Piece(text: tok.text, start: tok.start, end: tok.end, conf: tok.confidence))
                continue
            }
            interpolated = true
            guard let s = tok.start, let e = tok.end else {
                pieces.append(contentsOf: parts.map { Piece(text: $0, start: nil, end: nil, conf: tok.confidence) })
                continue
            }
            let weights = parts.map { Double(max($0.trimmingCharacters(in: .whitespaces).count, 1)) }
            let total = weights.reduce(0, +)
            var cursor = s
            for (i, part) in parts.enumerated() {
                let next = i == parts.count - 1 ? e : cursor + (e - s) * weights[i] / total
                pieces.append(Piece(text: part, start: cursor, end: next, conf: tok.confidence))
                cursor = next
            }
        }

        // Merge pieces into words: a new word starts at leading whitespace or
        // at a no-space-script boundary.
        var words: [Piece] = []
        for piece in pieces {
            guard var last = words.last else {
                words.append(piece)
                continue
            }
            let first = piece.text.first!
            // DictationTranscriber runs carry a TRAILING space ("Akşam "),
            // SpeechTranscriber runs a leading one (" are"); both mean a new word.
            let startsWord = first.isWhitespace
                || (last.text.last?.isWhitespace ?? false)
                || (last.text.last.map(isNoSpaceScript) ?? false)
                || isNoSpaceScript(first)
            let isPunct = piece.text.allSatisfy { $0.isPunctuation || $0.isSymbol }
            if startsWord && !(isPunct && !first.isWhitespace) {
                words.append(piece)
            } else {
                last.text += piece.text
                if last.start == nil { last.start = piece.start }
                if let e = piece.end { last.end = max(last.end ?? e, e) }
                if let c = piece.conf {
                    let w = last.confWeight + piece.confWeight
                    last.conf = ((last.conf ?? 0) * last.confWeight + c * piece.confWeight) / w
                    last.confWeight = w
                }
                words[words.count - 1] = last
            }
        }

        // Move trailing whitespace onto the front of the next word, so every
        // word reads "leading spaces + text" whichever engine produced it.
        for i in words.indices where i + 1 < words.count {
            let t = words[i].text
            let core = t.reversed().drop(while: { $0.isWhitespace })
            let trailing = t.count - core.count
            if trailing > 0, core.count > 0 {
                words[i].text = String(t.dropLast(trailing))
                words[i + 1].text = String(t.suffix(trailing)) + words[i + 1].text
            }
        }
        if var lastWord = words.last {
            while lastWord.text.last?.isWhitespace == true { lastWord.text.removeLast() }
            words[words.count - 1] = lastWord
        }

        // Fill missing times from neighbours, then clamp to monotonic.
        var out: [AppleSpeechWordOut] = []
        var lastEnd = 0.0
        for (i, w) in words.enumerated() {
            let start = w.start ?? lastEnd
            var end = w.end ?? (words[(i + 1)...].first { $0.start != nil }?.start ?? start)
            let s = max(start, lastEnd)
            end = max(end, s)
            out.append(AppleSpeechWordOut(text: w.text,
                                          startMs: Int((s * 1000).rounded()),
                                          endMs: Int((end * 1000).rounded()),
                                          confidence: w.conf))
            lastEnd = s
        }
        // A transcript never starts with a space.
        if var first = out.first, first.text.first?.isWhitespace == true {
            first = AppleSpeechWordOut(text: String(first.text.drop(while: { $0.isWhitespace })),
                                       startMs: first.startMs, endMs: first.endMs,
                                       confidence: first.confidence)
            out[0] = first
        }
        out.removeAll { $0.text.isEmpty }
        let text = out.map(\.text).joined()
        var confSum = 0.0, confW = 0.0
        for w in out {
            guard let c = w.confidence else { continue }
            let weight = Double(max(w.text.trimmingCharacters(in: .whitespaces).count, 1))
            confSum += c * weight
            confW += weight
        }
        let confidence: Double? = confW > 0 ? confSum / confW : nil
        return AppleSpeechResultOut(text: text, locale: locale, words: out, confidence: confidence,
                                    engine: engine.rawValue, interpolated: interpolated)
    }

    /// "a bc  d" -> ["a", " bc", "  d"]: each part keeps its leading spaces.
    static func splitKeepingLeadingSpace(_ s: String) -> [String] {
        var parts: [String] = []
        var cur = ""
        var sawText = false
        for ch in s {
            if ch.isWhitespace {
                if sawText {
                    parts.append(cur)
                    cur = ""
                    sawText = false
                }
                cur.append(ch)
            } else {
                cur.append(ch)
                sawText = true
            }
        }
        if !cur.isEmpty {
            if !sawText, !parts.isEmpty { parts[parts.count - 1] += cur } else { parts.append(cur) }
        }
        return parts
    }

    /// Scripts written without spaces between words.
    static func isNoSpaceScript(_ ch: Character) -> Bool {
        for scalar in ch.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30FF, // Hiragana, Katakana
                 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F, // Han
                 0x3000...0x303F, 0xFF00...0xFFEF, // CJK punctuation, fullwidth forms
                 0x0E00...0x0E7F, 0x0E80...0x0EFF, 0x1000...0x109F, 0x1780...0x17FF: // Thai, Lao, Myanmar, Khmer
                return true
            default: continue
            }
        }
        return false
    }

    // MARK: Helpers

    static func bcp47(_ locale: Locale) -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            return locale.identifier(.bcp47)
        }
        return locale.identifier.replacingOccurrences(of: "_", with: "-")
    }

    static func map(_ error: Error, fallback: AppleSpeechCode) -> AppleSpeechCoreError {
        if let e = error as? AppleSpeechCoreError { return e }
        if error is CancellationError { return AppleSpeechCoreError(.cancelled) }
        let ns = error as NSError
        if #available(iOS 26.0, macOS 26.0, *), ns.domain == SFSpeechError.errorDomain {
            switch SFSpeechError.Code(rawValue: ns.code) {
            case .cannotAllocateUnsupportedLocale?:
                return AppleSpeechCoreError(.unsupportedLocale, ns.localizedDescription)
            case .noModel?, .assetLocaleNotAllocated?, .tooManyAssetLocalesAllocated?:
                return AppleSpeechCoreError(.assetsFailed, ns.localizedDescription)
            case .audioDisordered?, .unexpectedAudioFormat?, .incompatibleAudioFormats?:
                return AppleSpeechCoreError(.decode, ns.localizedDescription)
            default:
                break
            }
        }
        return AppleSpeechCoreError(fallback, "\(ns.domain) \(ns.code): \(ns.localizedDescription)")
    }
}
