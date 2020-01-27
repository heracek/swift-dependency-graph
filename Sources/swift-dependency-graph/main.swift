import Foundation
import NIO
import swift_dependency_graph_lib
import IOKit.pwr_mgt
import Commander

class System {
    /// prevent system going to sleep. Returns an id you have to supply to re-enable system sleep
    class func preventSleep(reason:String) -> IOPMAssertionID? {
        var assertionID = IOPMAssertionID(0)
        let success = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                  IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                  reason as CFString,
                                                  &assertionID)
        if success == kIOReturnSuccess {
            return assertionID
        }
        return nil
    }
    
    /// re-enable system sleep. Pass in the id returned from the matching preventSleep() call
    class func allowSleep(id : IOPMAssertionID) {
        IOPMAssertionRelease(id)
    }
}

func run(_ file: String, patch: Bool, rebuild: String) {
    let startTime = Date()
    let id = System.preventSleep(reason: "Swift Dependency Graph")

    let url = "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json"

    do {
        let packages: Packages
        // load json that is already there
        if patch {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            let packageList = try JSONDecoder().decode(Packages.Container.self, from: data)
            packages = try Packages(packages: packageList)
            try packages.removePackage(rebuild)
        } else {
            packages = try Packages()
        }
        try packages.import(url: url)
        try packages.save(filename: file)
    } catch {
        print(error)
    }
    print("Dependency generation took \(Int(-startTime.timeIntervalSinceNow)) seconds")
    if let id = id {
        System.allowSleep(id: id)
    }
}

let rootPath = #file.split(separator: "/", omittingEmptySubsequences: false).dropLast(3).joined(separator: "/")

command(
    Option<String>("output", default: rootPath + "/dependencies.json"),
    Flag("patch", default:true, flag:"p", description: "Patch dependencies json"),
    Option<String>("rebuild", default: "")
) { path, patch, rebuild in
    run(path, patch: patch, rebuild: rebuild)
}.run()
