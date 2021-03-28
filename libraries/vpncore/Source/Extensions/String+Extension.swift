//
//  String+Extension.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public extension String {
    
    func contains(_ string: String) -> Bool {
        return self.range(of: string, options: NSString.CompareOptions.caseInsensitive) != nil ? true : false
    }
    
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = self as NSString
            let results = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
            return results.map { nsString.substring(with: $0.range) }
        } catch let error {
            PMLog.D("Invalid regex: \(error.localizedDescription)", level: .debug)
            return []
        }
    }
    
    func hasMatches(for regex: String) -> Bool {
        return !matches(for: regex).isEmpty
    }
    
    func preg_replace_none_regex (_ partten: String, replaceto: String) -> String {
        return self.replacingOccurrences(of: partten, with: replaceto, options: NSString.CompareOptions.caseInsensitive, range: nil)
    }
    
    func preg_replace (_ partten: String, replaceto: String) -> String {
        let options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
        do {
            let regex = try NSRegularExpression(pattern: partten, options: options)
            let replacedString = regex.stringByReplacingMatches(in: self, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: self.count), withTemplate: replaceto)
            if !replacedString.isEmpty {
                return replacedString
            }
        } catch let ex as NSError {
            PMLog.D("\(ex)", level: .debug)
        }
        return self
    }
    
    static func randomString(length: Int) -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.count)
        var randomString = ""
        
        for _ in 0..<length {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
            let newCharacter = allowedChars[randomIndex]
            randomString += String(newCharacter)
        }
        
        return randomString
    }
    
    func encodeBase64() -> String {
        let utf8str = self.data(using: String.Encoding.utf8)
        let base64Encoded = utf8str!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        return base64Encoded
    }
    
    func decodeBase64() -> String {
        let decodedData = Data(base64Encoded: self, options: NSData.Base64DecodingOptions(rawValue: 0))
        let decodedString = NSString(data: decodedData!, encoding: String.Encoding.utf8.rawValue)
        return decodedString! as String
    }
    
    func decodeBase64() -> Data {
        let decodedData = Data(base64Encoded: self, options: NSData.Base64DecodingOptions(rawValue: 0))
        return decodedData!
    }
}

public extension String {
    
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        let range: Range<Index> = start..<end
        return String(self[range])
    }
}
