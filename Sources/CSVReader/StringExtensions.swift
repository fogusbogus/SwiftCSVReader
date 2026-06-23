//
//  StringExtensions.swift
//  CSVReader
//
//  Created by Matt Hogg on 21/06/2026.
//

import Foundation

public typealias TextAndEndIndex = (text: String, index: String.Index)

public extension StringProtocol {
	
	/// Extract a quoted region of text
	/// - Parameter startingAtIndex: Start position index
	/// - Returns: Text and post index
	func extractQuoted(_ startingAtIndex: String.Index? = nil) -> TextAndEndIndex {
		//For CSVs we have two types of quote - double and single
		if var starting = nextCharacterPosition(startingAtIndex ?? startIndex, where: {["'", "\""].contains($0)}) {
			let quote = nextCharacter(starting)
			var inside = false, finished = false
			var ret = ""
			while starting < endIndex && !finished {
				let char = nextCharacter(starting)!
				if char == quote {
					inside = !inside
					starting = self.index(after: starting)
				} else {
					if !inside {
						finished = true
					} else {
						starting = self.index(after: starting)
					}
				}
				if !finished {
					ret += String(char)
				}
			}
			return (ret, starting)
		}
		return ("", startingAtIndex ?? startIndex)
	}
	
	/// Remove outer whitespaces and newlines
	/// - Returns: Trimmed string
	func trim() -> String {
		return self.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	

	func afterIndex(_ this: any StringProtocol, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal) -> String.Index {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let range = self.range(of: this, options: compare, range: starting..<endIndex) {
			return range.upperBound
		}
		return endIndex
	}

	func removingOuter(_ character: Character) -> String {
		let character = String(character)
		if self.hasPrefix(character) && self.hasSuffix(character) {
			return self.extract(self.index(after: self.startIndex)..<self.index(before: self.endIndex))
		}
		return String(self)
	}
	
	func nextCharacterPosition(_ position: String.Index, where: ((Character) -> Bool)? = nil) -> String.Index? {
		guard position < index(endIndex, offsetBy: -1, limitedBy: startIndex) ?? startIndex else { return nil }
		var position = position
		if `where` == nil { return position }
		while position < endIndex && position >= startIndex {
			if `where`!(self[position]) {
				return position
			}
			position = index(position, offsetBy: 1, limitedBy: endIndex)!
		}
		return nil
	}
	func nextCharacter(_ position: String.Index, where: ((Character) -> Bool)? = nil) -> Character? {
		if let pos = nextCharacterPosition(position, where: `where`) {
			return self[pos]
		}
		return nil
	}
	func nextStringIndex(_ ofAny: [any StringProtocol], index: String.Index? = nil, offset: Int? = nil, options: String.CompareOptions = .literal) -> String.Index? {
		var start = index ?? startIndex
		if let offset {
			if offset < 0 {
				start = self.index(start, offsetBy: offset, limitedBy: startIndex)!
			} else {
				start = self.index(start, offsetBy: offset, limitedBy: endIndex)!
			}
		}
		return ofAny.compactMap({ item in
			return self.range(of: item, options: options, range: start..<endIndex)
		}).sorted(by: {$0.lowerBound < $1.lowerBound}).first?.lowerBound
	}
	

}

public extension StringProtocol {
	
	func extract(_ position: Int, _ count: Int) -> String {
		let position = [0, position].max()!
		guard let start = self.index(startIndex, offsetBy: position, limitedBy: endIndex) else { return "" }
		guard start < endIndex else { return "" }
		guard let end = self.index(start, offsetBy: count, limitedBy: endIndex) else { return String(self[start..<endIndex]) }
		return String(self[start..<end])
	}
	
	func extract(_ position: String.Index, _ count: Int) -> String {
		return String(self[position..<index(position, offsetBy: count, limitedBy: endIndex)!])
	}
	
	func extract(_ range: Range<String.Index>) -> String {
		return String(self[range])
	}

}


