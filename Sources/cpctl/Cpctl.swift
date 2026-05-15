import ArgumentParser

@main
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct Cpctl: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "cpctl",
        abstract: "ControlPlane command line interface.",
        discussion: """
            Communicate with the ControlPlane backend via its Unix socket.
            The ControlPlane menu-bar app must be running.
            """,
        subcommands: [
            StatusCommand.self,
            ProfilesCommand.self,
            RulesCommand.self,
            ActionsCommand.self,
            EvaluatorsCommand.self,
            PluginsCommand.self,
            SensorsCommand.self,
            ShortcutsCommand.self,
        ]
    )
}
