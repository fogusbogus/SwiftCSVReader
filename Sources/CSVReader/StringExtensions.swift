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
	
	func extractWord(_ startingAtIndex: String.Index? = nil) -> TextAndEndIndex{
		var starting = startingAtIndex ?? self.startIndex
		while starting < self.endIndex && (nextCharacter(starting)!.isWhitespace || nextCharacter(starting)!.isNewline) {
			starting = self.index(after: starting)
		}
		if starting == self.endIndex { return ("", endIndex) }
		
		//We now have a starting point where we can extract any alphanumeric until we meet a non-alphanumeric
		var ret: String = ""
		while starting < self.endIndex {
			let nextChar = nextCharacter(starting)!
			if !(nextChar.isNumber || nextChar.isLetter) {
				break
			}
			ret += String(nextChar)
			starting = self.index(after: starting)
		}
		return (ret, starting)
	}
	
	func hasPrefix(_ prefix: any StringProtocol, _ position: String.Index) -> Bool {
		guard !prefix.isEmpty else { return true }
		return self.extract(position, prefix.count) == prefix
	}
	
	func trim() -> String {
		return self.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	func beforeIndex(_ this: any StringProtocol, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal) -> String.Index {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let range = self.range(of: this, options: compare, range: starting..<endIndex) {
			return range.lowerBound
		}
		return startIndex
	}
	func afterIndex(_ this: any StringProtocol, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal) -> String.Index {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let range = self.range(of: this, options: compare, range: starting..<endIndex) {
			return range.upperBound
		}
		return endIndex
	}
	func afterIndex(_ anyOf: [any StringProtocol], startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal) -> String.Index {
		let candidates = anyOf.map {afterIndex($0, startingAtIndex: startingAtIndex, startingAtPos: startingAtPos, compare: compare)}
		if candidates.count > 0 {
			return self.index(after: candidates.min()!)
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
	
	func before(_ this: any StringProtocol, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal, allIfMissing: Bool? = nil) -> String {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let range = self.range(of: this, options: compare, range: starting..<endIndex) {
			return String(self[startIndex..<range.lowerBound])
		}
		if (allIfMissing ?? false) { return String(self) }
		return ""
	}
	func after(_ this: any StringProtocol, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal, allIfMissing: Bool? = nil) -> String {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let range = self.range(of: this, options: compare, range: starting..<endIndex) {
			return String(self[range.upperBound..<endIndex])
		}
		if (allIfMissing ?? false) { return String(self) }
		return ""
	}
	func before(_ anyOfThese: [any StringProtocol], startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal, allIfMissing: Bool? = nil) -> String {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let found = anyOfThese.compactMap({ this in
			return self.range(of: this, options: compare, range: starting..<endIndex)
		}).sorted(by: {$0.lowerBound < $1.lowerBound}).first {
			return String(self[starting..<found.lowerBound])
		}
		if (allIfMissing ?? false) { return String(self) }
		return ""
	}
	
	func after(_ anyOfThese: [any StringProtocol], startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, compare: String.CompareOptions = .literal, allIfMissing: Bool? = nil) -> String {
		let starting = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0)
		if let found = anyOfThese.compactMap({ this in
			return self.range(of: this, options: compare, range: starting..<endIndex)
		}).sorted(by: {$0.lowerBound < $1.lowerBound}).first {
			return String(self[found.upperBound..<endIndex])
		}
		if (allIfMissing ?? false) { return String(self) }
		return ""
	}
	
	
	func nextCharacterPosition(_ position: Int, where: ((Character) -> Bool)? = nil) -> Int? {
		var position = position
		if `where` == nil { return position }
		while let index = self.index(startIndex, offsetBy: position, limitedBy: endIndex), index < endIndex {
			if `where`!(self[self.index(startIndex, offsetBy: position)]) {
				return position
			}
			position += 1
		}
		return nil
	}
	func nextCharacter(_ position: Int, where: ((Character) -> Bool)? = nil) -> Character? {
		if let pos = nextCharacterPosition(position, where: `where`) {
			return self[self.index(startIndex, offsetBy: pos)]
		}
		return nil
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
	
	func previousCharacterPosition(_ position: Int, where: ((Character) -> Bool)? = nil) -> Int? {
		guard position > 0 else { return nil }
		var position = position - 1
		if `where` == nil { return position }
		while position >= 0, let index = self.index(startIndex, offsetBy: position, limitedBy: endIndex), index < endIndex {
			if `where`!(self[self.index(startIndex, offsetBy: position)]) {
				return position
			}
			position -= 1
		}
		return nil
	}
	func previousCharacter(_ position: Int, where: ((Character) -> Bool)? = nil) -> Character? {
		if let pos = previousCharacterPosition(position, where: `where`) {
			return self[self.index(startIndex, offsetBy: pos)]
		}
		return nil
	}
	
	func previousCharacterPosition(_ position: String.Index, where: ((Character) -> Bool)? = nil) -> String.Index? {
		guard position > self.startIndex else { return nil }
		var position = self.index(position, offsetBy: -1, limitedBy: startIndex)!
		if `where` == nil { return position }
		while position > startIndex && position < endIndex {
			if `where`!(self[position]) {
				return position
			}
			position = self.index(position, offsetBy: -1, limitedBy: startIndex)!
		}
		return startIndex
	}
	func previousCharacter(_ position: String.Index, where: ((Character) -> Bool)? = nil) -> Character? {
		if let pos = previousCharacterPosition(position, where: `where`) {
			return self[pos]
		}
		return nil
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
	
	func extract(_ range: ClosedRange<Int>) -> String {
		let lower = self.index(startIndex, offsetBy: range.lowerBound, limitedBy: startIndex)!
		let higher = self.index(endIndex, offsetBy: range.upperBound, limitedBy: endIndex)!
		return String(self[lower..<higher])
	}
	func extract(_ range: Range<Int>) -> String {
		let lower = self.index(startIndex, offsetBy: range.lowerBound, limitedBy: startIndex)!
		let higher = self.index(endIndex, offsetBy: range.upperBound, limitedBy: endIndex)!
		return String(self[lower..<higher])
	}
	func extract(_ range: ClosedRange<String.Index>) -> String {
		return String(self[range])
	}
	func extract(_ range: Range<String.Index>) -> String {
		return String(self[range])
	}
	
	func starts(position: Int, withAny: [any StringProtocol], longestPreferential: Bool = true) -> (any StringProtocol)? {
		let toFind = withAny.sorted(by: {$0.count > $1.count})
		return toFind.first(where: {
			self.extract(position, $0.count) == $0
		})
	}
}
public enum IndexPosition {
	case start, end
}

/*
 Next/Previous Index of something
 */
public extension StringProtocol {
	func nextIndexOf(_ this: any StringProtocol, options: String.CompareOptions, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, position: IndexPosition = .start) -> String.Index? {
		guard let start = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0, limitedBy: endIndex) else { return nil }
		if let found = self.range(of: this, options: options, range: start..<endIndex) {
			if position == .end {
				return found.upperBound
			}
			return found.lowerBound
		}
		return nil
	}
	func nextIndexOf(_ anyOf: [any StringProtocol], options: String.CompareOptions, startingAtIndex: String.Index? = nil, startingAtPos: Int? = nil, position: IndexPosition = .start) -> String.Index? {
		guard let start = startingAtIndex ?? self.index(startIndex, offsetBy: startingAtPos ?? 0, limitedBy: endIndex) else { return nil }
		return anyOf.compactMap {
			if let found = self.range(of: $0, options: options, range: start..<endIndex) {
				if position == .end {
					return found.upperBound
				}
				return found.lowerBound
			}
			return nil
		}.first
	}
	
	func previousIndexOf(_ this: any StringProtocol, options: String.CompareOptions, beforeIndex: String.Index? = nil, beforePos: Int? = nil, position: IndexPosition = .start) -> String.Index? {
		var lastAllowedIndex = beforeIndex
		if lastAllowedIndex == nil {
			if let beforePos {
				lastAllowedIndex = self.index(startIndex, offsetBy: beforePos, limitedBy: endIndex)
			} else {
				lastAllowedIndex = endIndex
			}
		}
		var found: Range<String.Index>? = nil
		var nextIndex = startIndex
		while let candidate = self.range(of: this, options: options, range: nextIndex..<lastAllowedIndex!) {
			found = candidate
			nextIndex = self.index(after: nextIndex)
		}
		if let found {
			if position == .end {
				return found.upperBound
			}
			return found.lowerBound
		}
		return nil
	}
	func previousIndexOf(_ anyOf: [any StringProtocol], options: String.CompareOptions, beforeIndex: String.Index? = nil, beforePos: Int? = nil, position: IndexPosition = .start) -> String.Index? {
		let mapped = anyOf.compactMap {self.previousIndexOf($0, options: options, beforeIndex: beforeIndex, beforePos: beforePos, position: position)}
		return mapped.sorted(by: {$0 > $1}).first
	}
}

