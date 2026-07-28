//
//  PrepCoordinator.swift
//  TuneURL (SDK)
//
//  Prep-phase coordinator for podcast episodes/branches. Since DownloadCache
//  only ever hands back a complete local file (no partial/progressive
//  access), this is just a thin wrapper around Detector.processAudio —
//  no chunk-accumulation or decode-ahead machinery needed.
//
//  Requires the two Detector.swift fixes in Detector-fix.md (loop bound +
//  end-of-file match extraction) to correctly scan a whole episode.
//
//  STILL BLOCKED ON: how CYON options are represented — Match.swift has no
//  `options` field, so `isChooseYourOwnNarrative` / default-branch lookup
//  below is a placeholder until that's answered.
//

import Foundation

public struct TuneUrlMoment {
    public let timestamp: TimeInterval   // == Match.time
    public let match: Match
}

final class PrepCoordinator {

    let branchId: String

    private static var activeCoordinators: [String: PrepCoordinator] = [:]
    private static let registryQueue = DispatchQueue(label: "com.TuneURL.PrepCoordinator.registry")

    private init(branchId: String) {
        self.branchId = branchId
    }

    /// Entry point — call once you have a complete local file (from
    /// DownloadCache.cachedFile / DownloadCache.download's completion).
    static func beginPrep(branchId: String, fileURL: URL) {
        registryQueue.async {
            guard activeCoordinators[branchId] == nil else { return }   // already prepping/prepped
            let coordinator = PrepCoordinator(branchId: branchId)
            activeCoordinators[branchId] = coordinator
            coordinator.start(fileURL: fileURL)
        }
    }

    private func start(fileURL: URL) {
        Detector.processAudio(for: fileURL) { [weak self] matches in
            guard let self else { return }

            for match in matches {
                self.resolve(match)
            }

            PrepStore.shared.markComplete(forBranch: self.branchId)
            Self.registryQueue.async {
                Self.activeCoordinators[self.branchId] = nil
            }
        }
    }

    private func resolve(_ match: Match) {
        let moment = TuneUrlMoment(timestamp: TimeInterval(match.time), match: match)
        PrepStore.shared.save(moment, forBranch: branchId)

        // TODO: CYON detection + recursive default-branch prep.
        // Blocked on knowing how CYON options are represented — Match has no
        // `options` field. Once known, something like:
        //
        // if let defaultOption = cyonOptions(for: match)?.first(where: { $0.isDefault }) {
        //     DownloadCache.shared.cachedFile(for: defaultOption.playerItem) { localURL in
        //         guard let localURL else { return }
        //         PrepCoordinator.beginPrep(branchId: defaultOption.id, fileURL: localURL)
        //     }
        // }
    }
}
