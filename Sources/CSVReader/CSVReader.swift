// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


public protocol CSVFileReaderLogDelegate {
	func log(_ message: String)
}

extension Dictionary where Key == String, Value == Int {
	func valueOf(key: String) -> Value? {
		guard let myKey = self.keys.first(where: {$0 == key}) ?? self.keys.first(where: {$0.localizedCaseInsensitiveCompare(key) == .orderedSame}) else { return nil }
		return self[myKey]
	}
}

public class CSVFile {
	public init(data: String, withHeaders: Bool = true, encoding: String.Encoding = .utf8) {
		self.encoding = encoding
		self.reader.encoding = encoding
		self.reader.data = data
		self.reader.currentPos = data.startIndex
		if withHeaders {
			self.headers = reader.readHeaders()
		}
		self.rowIndexes = parse()
		self.currentLine = self.reader.readLine()
	}
	public init?(filePath: String, withHeaders: Bool = true, encoding: String.Encoding = .utf8) {
		guard FileManager.default.fileExists(atPath: filePath) else { return nil }
		let url = URL(filePath: filePath, directoryHint: .notDirectory)
		guard let data = try? String(contentsOf: url, encoding: encoding) else { return nil }
		self.encoding = encoding
		self.reader.encoding = encoding
		self.reader.data = data
		self.reader.currentPos = data.startIndex
		if withHeaders {
			self.headers = reader.readHeaders()
		}
		self.rowIndexes = parse()
		self.currentLine = self.reader.readLine()
	}
	public init?(url: URL, withHeaders: Bool = true, encoding: String.Encoding = .utf8) {
		guard let data = try? String(contentsOf: url, encoding: encoding) else { return nil }
		self.encoding = encoding
		self.reader.encoding = encoding
		self.reader.data = data
		self.reader.currentPos = data.startIndex
		if withHeaders {
			self.headers = reader.readHeaders()
		}
		self.rowIndexes = parse()
		self.currentLine = self.reader.readLine()
	}
	private var headers: [String:Int] = [:]
	private var reader: CSVFileReader = CSVFileReader(data: "")
	private var rowIndexes: [String.Index] = []
	private var encoding: String.Encoding = .utf8

	public var currentLine: [String] = []
	
	public func nextLine() {
		self.currentLine = self.reader.readLine()
	}
	
	public func readLine(at: String.Index) -> [String] {
		guard at < reader.data.endIndex else {
			return []
		}
		let cp = reader.currentPos
		reader.currentPos = at
		let cl = currentLine
		nextLine()
		let ret = currentLine
		currentLine = cl
		reader.currentPos = cp
		return ret
	}
	
	public var atEndOfFile: Bool { reader.atEnd }
	public var atEndOfLine: Bool { reader.atEndOfLine() }
	
	public subscript (_ headerName: String) -> String? {
		get {
			guard let key = headers.keys.first(where: {$0.localizedStandardCompare(headerName) == .orderedSame}) ?? headers.keys.first(where: {$0.localizedCaseInsensitiveCompare(headerName) == .orderedSame}) else { return nil }
			if currentLine.count > headers[key]! {
				return currentLine[headers[key]!]
			}
			return nil
		}
	}
	
	public subscript (_ headerName: String, row: Int) -> String? {
		get {
			if let key = headers.keys.first(where: {$0.localizedStandardCompare(headerName) == .orderedSame}) ?? headers.keys.first(where: {$0.localizedCaseInsensitiveCompare(headerName) == .orderedSame}) {
				if row < rowIndexes.count {
					let rowIndex = rowIndexes[row]
					let data = readLine(at: rowIndex)
					let colIndex = headers[key]!
					if colIndex < data.count {
						return data[colIndex]
					}
				}
				return nil
			} else {
				if let col = self.cellReference("\(headerName)0") {
					if col.row < rowIndexes.count {
						let rowIndex = rowIndexes[col.row]
						let data = readLine(at: rowIndex)
						if col.col < data.count {
							return data[col.col]
						}
					}
					return nil
				} else {
					return nil
				}
			}
		}
	}
	
	public subscript (_ index: Int) -> String? {
		get {
			if (0..<currentLine.count).contains(index) {
				return currentLine[index]
			}
			return nil
		}
	}
	
	public func cellReference(_ colRow: String) -> (row: Int, col: Int)? {
		let col = colRow.filter {$0.isLetter}.uppercased()
		let row = Int(colRow.filter {$0.isNumber})
		var colIndex = 0
		let baseAscii = Character("A").asciiValue!
		col.forEach { colChr in
			colIndex *= 26
			colIndex += Int(colChr.asciiValue! - baseAscii)
		}
		if let row {
			return (row: row, col: colIndex)
		}
		return nil
	}
	
	public func parse() -> [String.Index] {
		let cp = reader.currentPos
		reader.currentPos = reader.data.startIndex
		var ret: [String.Index] = []
		while !reader.atEnd {
			ret.append(reader.currentPos)
			_ = reader.readLine()
		}
		reader.currentPos = cp
		return ret
	}
	
	public func `get`<T>(_ headerName: String, _ defaultValue: T) -> T {
		guard let key = headers.keys.first(where: {$0.localizedStandardCompare(headerName) == .orderedSame}) ?? headers.keys.first(where: {$0.localizedCaseInsensitiveCompare(headerName) == .orderedSame}) else { return defaultValue }
		if currentLine.count > headers[key]! {
			return currentLine[headers[key]!] as? T ?? defaultValue
		}
		return defaultValue
	}
	
	public func `get`<T>(_ index: Int, _ defaultValue: T) -> T {
		guard (0..<currentLine.count).contains(index) else { return defaultValue }
		return currentLine[index] as? T ?? defaultValue
	}
}

public class CSVFileReader {
	
	public init(data: String, currentPos: String.Index? = nil, encoding: String.Encoding? = nil) {
		self.data = data
		self.currentPos = currentPos ?? data.startIndex
		self.encoding = encoding ?? self.encoding
	}
	
	public var logger: CSVFileReaderLogDelegate? = nil
	
	var data: String
	var encoding: String.Encoding = .utf8
	var logCurrentPosChange = ""
	var currentPos: String.Index {
		didSet {
			if !logCurrentPosChange.isEmpty {
				logger?.log("\(logCurrentPosChange): \(oldValue) -> \(currentPos)")
				logCurrentPosChange = ""
			}
		}
	}
	public var atEnd: Bool {
		currentPos >= data.endIndex
	}
	
	public func atEndOfLine() -> Bool {
		if let next = data.nextCharacter(currentPos, where: { $0.isNewline || !$0.isWhitespace }) {
			return next.isNewline
		}
		
		//End of file is end of line
		return true
	}
	
	public func readHeaders() -> [String:Int] {
		logger?.log("<< readHeaders() >>")
		currentPos = data.startIndex
		let items = readLine()
		var ret: [String:Int] = [:]
		(0..<items.count).forEach { index in
			ret[items[index]] = index
		}
		return ret
	}
	
	public func readDataLine(headers: [String:Int]) -> [String:String] {
		logger?.log("<< readDataLine(headers) >>")
		let items = readLine()
		var ret: [String:String] = [:]
		headers.keys.forEach { key in
			let index = headers[key]!
			if items.count > index {
				ret[key] = items[index]
			}
			else {
				ret[key] = ""
			}
		}
		return ret
	}
	
	public func readLine() -> [String] {
		logger?.log("<< readLine() >>")
		var ret: [String] = []
		while !atEndOfLine() {
			ret.append(readNext())
		}
		logger?.log("  - \(ret.count) items read")
		currentPos = data.afterIndex("\n", startingAtIndex: currentPos)
		return ret
	}
	
	public func readNext(startingAt: String.Index? = nil) -> String {
		guard !atEnd else { return "" }
		guard !atEndOfLine() else {
			currentPos = data.afterIndex("\n", startingAtIndex: startingAt ?? currentPos)
			return ""
		}
		currentPos = startingAt ?? currentPos
		let nonBlank: (Character) -> Bool = { !$0.isWhitespace && !$0.isNewline }
		if let next = data.nextCharacter(currentPos, where: nonBlank ) {
			if next == "'" || next == "\"" {
				let text = data.extractQuoted(currentPos)
				logCurrentPosChange = "quoted(\(text))"
				currentPos = text.index
				if !atEndOfLine() {
					//We've only extracted the quote item (we need to remove the outer quotes as well), so look for the next EOL or comma
					logCurrentPosChange = "after quoted"
					if data.extract(currentPos, 2) == "\r\n" {
						currentPos = data.index(currentPos, offsetBy: 2, limitedBy: data.endIndex)!
					} else {
						if data.extract(currentPos, 1) == "," {
							currentPos = data.index(after: currentPos)
						}
					}
				}
				return text.text.removingOuter(next)
			}
			if let upTo = data.nextStringIndex(["\r\n", "\n", ","], index: currentPos) {
				let text = data.extract(currentPos..<upTo).trim()
				logCurrentPosChange = "upto(\(text)\(data.extract(upTo, 1)))"
				currentPos = upTo //data.index(after: upTo)
				if data.extract(currentPos, 2) == "\r\n" {
					currentPos = data.index(currentPos, offsetBy: 2, limitedBy: data.endIndex)!
				} else {
					if data.extract(currentPos, 1) == "," {
						currentPos = data.index(after: currentPos)
					}
				}
				return text
			} else {
				let pos = currentPos
				currentPos = data.endIndex
				return data.extract(pos..<currentPos)
			}
		}
		currentPos = data.endIndex
		return ""
		
	}
}

