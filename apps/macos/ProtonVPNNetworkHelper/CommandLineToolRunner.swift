//
//  CommandLineToolRunner.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

struct CommandLineToolRunner {
    
    private static let pfctl = "/sbin/pfctl"
    private static let undoArguments = ["-d"]
    private static let stateArguments = ["-si"]
    private static let rulesArguments = ["-sr"]
    
    private static let grep = "/usr/bin/grep"
    private static let grepEnabledArguments = ["Status: Enabled"]
    
    private static let launchctl = "/bin/launchctl"
    private static let unloadArguments = ["unload", "/Library/LaunchDaemons/ch.protonvpn.ProtonVPNNetworkHelper.plist"]
    
    private static let rm = "/bin/rm"
    private static let rmArguments = ["/Library/PrivilegedHelperTools/ch.protonvpn.ProtonVPNNetworkHelper", "/Library/LaunchDaemons/ch.protonvpn.ProtonVPNNetworkHelper.plist"]
    
    /// Used to run commands in serial
    private static let runnerQueue = DispatchQueue(label: "ch.protonvpn.networkhelper")
    
    /// Check if any PF firewall is enabled (regardless of rules)
    static func checkIfAnyFirewallIsEnabled(logger: AppProtocol, completion: @escaping (NSNumber) -> ()) {
        checkPfEnabled(logger: logger) { (task) in
            let terminationStatus = NSNumber(value: task.terminationStatus)
            logger.log("Any enabled result: \(terminationStatus)\n")
            completion(terminationStatus)
        }
    }
    
    /// Check if our firewall is enabled
    static func checkIfFirewallIsEnabled(forServer address: String, logger: AppProtocol, completion: @escaping (NSNumber) -> ()) {
        checkPfEnabled(logger: logger) { (task) in
            let terminationStatus = NSNumber(value: task.terminationStatus)
            var loggingOutput = "Enabled result: \(terminationStatus)\n"
            guard terminationStatus == 0 else {
                logger.log(loggingOutput)
                completion(terminationStatus)
                return
            }
            
            // Once the firewall is confirmed to be enabled, check the firewall rules
            // pfctl -sr | grep <address>
            let grepAdressInputPipe = Pipe()
            
            let rulesOutputHandler =  { (file: FileHandle!) -> Void in
                let data = file.availableData
                grepAdressInputPipe.fileHandleForWriting.write(data)
                grepAdressInputPipe.fileHandleForWriting.closeFile()
                
                guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue), output.length != 0 else { return }
                loggingOutput.append(output as String)
            }
            
            let firewallRulesPipe = Pipe()
            firewallRulesPipe.fileHandleForReading.readabilityHandler = rulesOutputHandler
            
            let pfctlRulesProcess = Process()
            pfctlRulesProcess.launchPath = self.pfctl
            pfctlRulesProcess.arguments = self.rulesArguments
            pfctlRulesProcess.standardOutput = firewallRulesPipe
            
            let grepAddressProcess = Process()
            grepAddressProcess.launchPath = self.grep
            grepAddressProcess.arguments = [address]
            grepAddressProcess.standardInput = grepAdressInputPipe
            
            grepAddressProcess.terminationHandler = { task in
                let terminationStatus = NSNumber(value: task.terminationStatus)
                
                if terminationStatus != 0 {
                    loggingOutput.append("Address present result: \(terminationStatus)")
                    logger.log(loggingOutput)
                }
                
                completion(terminationStatus)
            }
            
            pfctlRulesProcess.launch()
            pfctlRulesProcess.waitUntilExit()
            grepAddressProcess.launch()
            grepAddressProcess.waitUntilExit()
        }
    }
    
    static func enableFirewall(with file: URL, completion: @escaping (NSNumber) -> ()) {
        runPfctl(arguments: undoArguments) { _ in
            let arguments = self.applyArguments(file: file)
            self.runPfctl(arguments: arguments, completion: completion)
        }
    }
    
    static func disableFirewall(completion: @escaping (NSNumber) -> ()) {
        runPfctl(arguments: undoArguments, completion: completion)
    }
    
    static func unloadFromLaunchd(completion: @escaping (NSNumber) -> ()) {
        runnerQueue.async {
            let process = Process()
            process.launchPath = launchctl
            process.arguments = unloadArguments
            
            process.terminationHandler = { task in
                completion(NSNumber(value: task.terminationStatus))
            }
            
            process.launch()
        }
    }
    
    static func uninstall(completion: @escaping (NSNumber) -> ()) {
        runnerQueue.async {
            let process = Process()
            process.launchPath = rm
            process.arguments = rmArguments
            
            process.terminationHandler = { task in
                unloadFromLaunchd(completion: { result in
                    completion(NSNumber(value: task.terminationStatus))
                })
            }
            
            process.launch()
        }
    }
    
    // MARK:- Private functions
    private static func applyArguments(file: URL) -> [String] {
        let configFile = file.path
        return ["-Fa", "-f", configFile, "-e"]
    }
    
    private static func checkPfEnabled(logger: AppProtocol, completion: @escaping (Process) -> Void) {
        runnerQueue.async {
            let grepEnabledInputPipe = Pipe()
            
            let statusOutputHandler =  { (file: FileHandle!) -> Void in
                let data = file.availableData
                grepEnabledInputPipe.fileHandleForWriting.write(data)
                grepEnabledInputPipe.fileHandleForWriting.closeFile()
                
                guard let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue), output.length != 0 else { return }
                logger.log(output as String)
            }
            
            // First check that the firewall is enabled
            // pfctl -si | grep 'Status: Enabled'
            let firewallStatusPipe = Pipe()
            firewallStatusPipe.fileHandleForReading.readabilityHandler = statusOutputHandler
            
            let pfctlStatusProcess = Process()
            pfctlStatusProcess.launchPath = pfctl
            pfctlStatusProcess.arguments = stateArguments
            pfctlStatusProcess.standardOutput = firewallStatusPipe
            
            let grepEnabledProcess = Process()
            grepEnabledProcess.launchPath = grep
            grepEnabledProcess.arguments = grepEnabledArguments
            grepEnabledProcess.standardInput = grepEnabledInputPipe
            
            grepEnabledProcess.terminationHandler = { task in
                completion(task)
            }
                
            pfctlStatusProcess.launch()
            pfctlStatusProcess.waitUntilExit()
            grepEnabledProcess.launch()
            grepEnabledProcess.waitUntilExit()
        }
    }
    
    private static func runPfctl(arguments: [String], completion: @escaping ((NSNumber) -> ())) {
        runnerQueue.async {
            let process = Process()
            process.launchPath = pfctl
            process.arguments = arguments
            
            process.terminationHandler = { task in
                completion(NSNumber(value: task.terminationStatus))
            }
            
            process.launch()
        }
    }
}
