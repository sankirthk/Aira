import AppKit
import Sparkle

@MainActor
final class AiraSparkleUserDriver: NSObject, SPUUserDriver {
    private let standardUserDriver: SPUStandardUserDriver
    private let hostBundle: Bundle
    private var promptWindowController: AppUpdatePromptWindowController?
    private var lastPresentedVersion: String?

    init(hostBundle: Bundle = .main) {
        self.hostBundle = hostBundle
        self.standardUserDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        super.init()
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        standardUserDriver.show(request, reply: reply)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        standardUserDriver.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard appcastItem.isInformationOnlyUpdate == false else {
            standardUserDriver.showUpdateFound(with: appcastItem, state: state, reply: reply)
            return
        }

        lastPresentedVersion = appcastItem.displayVersionString

        presentPrompt(
            content: .updateFound(version: appcastItem.displayVersionString),
            primaryReply: .install,
            secondaryReply: .dismiss,
            reply: reply
        )
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        standardUserDriver.showUpdateReleaseNotes(with: downloadData)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        standardUserDriver.showUpdateReleaseNotesFailedToDownloadWithError(error)
    }

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        standardUserDriver.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        standardUserDriver.showUpdaterError(error, acknowledgement: acknowledgement)
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        standardUserDriver.showDownloadInitiated(cancellation: cancellation)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        standardUserDriver.showDownloadDidReceiveExpectedContentLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        standardUserDriver.showDownloadDidReceiveData(ofLength: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        standardUserDriver.showDownloadDidStartExtractingUpdate()
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        standardUserDriver.showExtractionReceivedProgress(progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        let fallbackVersion = hostBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "latest"
        let version = lastPresentedVersion ?? fallbackVersion

        presentPrompt(
            content: .readyToInstall(version: version),
            primaryReply: .install,
            secondaryReply: .dismiss,
            reply: reply
        )
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        standardUserDriver.showInstallingUpdate(withApplicationTerminated: applicationTerminated, retryTerminatingApplication: retryTerminatingApplication)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        standardUserDriver.showUpdateInstalledAndRelaunched(relaunched, acknowledgement: acknowledgement)
    }

    func dismissUpdateInstallation() {
        dismissPrompt()
        standardUserDriver.dismissUpdateInstallation()
    }

    func showUpdateInFocus() {
        if let promptWindowController {
            promptWindowController.focus()
        } else {
            standardUserDriver.showUpdateInFocus()
        }
    }

    private func presentPrompt(
        content: AppUpdatePromptContent,
        primaryReply: SPUUserUpdateChoice,
        secondaryReply: SPUUserUpdateChoice,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        dismissPrompt()

        let promptWindowController = AppUpdatePromptWindowController(
            content: content,
            onPrimaryAction: { [weak self] in
                self?.dismissPrompt()
                reply(primaryReply)
            },
            onSecondaryAction: { [weak self] in
                self?.dismissPrompt()
                reply(secondaryReply)
            }
        )

        self.promptWindowController = promptWindowController
        promptWindowController.show()
    }

    private func dismissPrompt() {
        promptWindowController?.closePrompt()
        promptWindowController = nil
    }
}
