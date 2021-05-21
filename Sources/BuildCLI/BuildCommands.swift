import ArgumentParser
import Machines
import NonStdIO
import Foundation

public class BuildCLIConfig {
  public static var shared: BuildCLIConfig = .init()
  
  public var apiURL = "https://api-staging.blink.build";
  public var auth0: Auth0 = Auth0(config: .init(
    clientId: "x7RQ8NR862VscbotFSfu2VO7PEj55ExK",
    domain: "dev-i8bp-l6b.us.auth0.com",
    scope: "offline_access+openid+profile+read:build+write:build",
    audience: "blink.build"
  ))
  
  public var tokenProvider: FileAuthTokenProvider
  
  public init() {
    tokenProvider = FileAuthTokenProvider(auth0: auth0)
  }
}

func machine() -> Machines.Machine {
  Machines.machine(baseURL: BuildCLIConfig.shared.apiURL, auth: .bearer(BuildCLIConfig.shared.tokenProvider))
}

func containers() -> Machines.Containers {
  machine().containers
}

public struct BuildCommands: NonStdIOCommand {
  public init() {}
  
  public static var configuration = CommandConfiguration(
    commandName: "build",
    abstract: "build is a command line interface for your dev environments",
    subcommands: [
      MachineCommands.self,
      BalanceCommands.self,
      SSHKeysCommands.self,
      ContainersCommands.self,
      DeviceCommands.self,
      Up.self,
      Down.self,
      PS.self,
      SSH.self,
      MOSH.self,
    ]
  )
  
  @OptionGroup public var verboseOptions: VerboseOptions
  public var io = NonStdIO.standart
  
  struct Up: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Starts container and machine if needed"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    @Option(
      name: .shortAndLong,
      help: "image of container"
    )
    var image: String?
    
    @Argument(
      help: "name of the container"
    )
    var containerName: String
    
    func validate() throws {
      try validateContainerName(containerName)
    }
    
    func run() throws {
      _ = try machine().containers
        .start(name: containerName, image: image ?? containerName)
  //      .spinner(stdout: stdout, message: "creating container")
        .onMachineNotStarted {
  //        stdout <<< "Machine is not started."
  //        let doStart = Input.readBool(prompt: "Start machine?", defaultValue: true, secure: false)
  //        if !doStart {
  //          return .just(false)
  //        }
          return machine()
            .start(
              region: Machines.defaultRegion,
              size: Machines.defaultSize
            ).map { _ in return true }
            .delay(.seconds(3)) // wait a little bit to start
  //          .spinner(stdout: stdout, message: "Starting machine")
        }.awaitOutput()!
    }
  }

  struct Down: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Stops container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    @Argument(
      help: "name of the container"
    )
    var name: String
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      let res = try machine().containers.stop(name: name).awaitOutput()!
      print(res)
    }
  }
  
  
  struct PS: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "List running containers"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    func run() throws {
      let res = try containers().list().awaitOutput()!["containers"] as? [String]
      for line in res ?? [] {
        print(line)
      }
    }
  }


  struct SSH: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "SSH to container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Flag(
      name: .customShort("A"),
      help: "Enables forwarding of the authentication agent connection"
    )
    var agent: Bool = false
    
    @Argument(
      help: "name of the container"
    )
    var name: String

    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      let ip = try machine().ip().awaitOutput()!
      let args = ["", "-c", "ssh -t \(agent ? "-A" : "") root@\(ip) \(name)"]
      
      printDebug("Executing command \"/bin/sh" + args.joined(separator: " ") + "\"")
      
      let cargs = args.map { strdup($0) } + [nil]
      
      execv("/bin/sh", cargs)
      
      fatalError("exec failed")
    }
  }

  struct MOSH: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "MOSH to container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument(
      help: "name of the container"
    )
    var name: String
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      let ip = try machine().ip().awaitOutput()!
      let args = ["", "-c", "mosh root@\(ip) \(name)"]
      let cargs = args.map { strdup($0) } + [nil]
      
      execv("/bin/sh", cargs)
      
      fatalError("exec failed")
    }
  }
}