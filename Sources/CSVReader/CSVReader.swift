// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


/// Providing an derived instance will allow logging output from the CSV converter
public protocol CSVFileReaderLogDelegate {
	func log(_ message: String)
}

extension Dictionary where Key == String, Value == Int {
	/// For our headers collection, this allows indexing by a caseless key
	/// - Parameter key: The key to look for
	/// - Returns: The value matched to the key
	func valueOf(key: String) -> Value? {
		guard let myKey = self.keys.first(where: {$0 == key}) ?? self.keys.first(where: {$0.localizedCaseInsensitiveCompare(key) == .orderedSame}) else { return nil }
		return self[myKey]
	}
}

/// CSV file processor
public class CSVFile {
	/// Initializer from some string data
	/// - Parameters:
	///   - data: String representation of the CSV file
	///   - withHeaders: Is the first row headers?
	///   - encoding: How the string is encoded.
	public init(data: String, withHeaders: Bool = true, encoding: String.Encoding = .utf8) {
		self.encoding = encoding
		self.reader.encoding = encoding
		self.reader.data = data
		self.reader.currentPos = data.startIndex
		if withHeaders {
			self.headers = reader.readHeaders()
		}
		self.rowIndexes = parse()
		self.currentLine = self.reader.readRow()
	}
	/// Initializer from some file path
	/// - Parameters:
	///   - filePath: Location of the csv data
	///   - withHeaders: Is the first row headers?
	///   - encoding: The encoding of the file
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
		self.currentLine = self.reader.readRow()
	}
	/// Initializer from a URL
	/// - Parameters:
	///   - url: The location of the csv data
	///   - withHeaders: Is the first row headers?
	///   - encoding: How is the data encoded
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
		self.currentLine = self.reader.readRow()
	}
	private var headers: [String:Int] = [:]
	private var reader: CSVFileReader = CSVFileReader(data: "")
	private var rowIndexes: [String.Index] = []
	private var encoding: String.Encoding = .utf8
	
	/// The current row's data
	public var currentLine: [String] = []
	
	/// Get the next row of data
	public func nextRow() {
		self.currentLine = self.reader.readRow()
	}
	
	/// Read the next row of data
	/// - Parameter at: Starting at string index
	/// - Returns: An array of data for the row
	public func readRow(at: String.Index) -> [String] {
		guard at < reader.data.endIndex else {
			return []
		}
		let cp = reader.currentPos
		reader.currentPos = at
		let cl = currentLine
		nextRow()
		let ret = currentLine
		currentLine = cl
		reader.currentPos = cp
		return ret
	}
	
	/// Is the data exhausted?
	public var atEndOfFile: Bool { reader.atEnd }
	/// A the end of a row? This will normally be true.
	public var atEndOfRow: Bool { reader.atEndOfRow() }
	
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
					let data = readRow(at: rowIndex)
					let colIndex = headers[key]!
					if colIndex < data.count {
						return data[colIndex]
					}
				}
				return nil
			} else {
				if let col = Self.cellReference("\(headerName)0") {
					if col.row < rowIndexes.count {
						let rowIndex = rowIndexes[col.row]
						let data = readRow(at: rowIndex)
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
	
	/// Calculate a cell reference (A1, BC45, etc.)
	/// - Parameter colRow: The colRow reference
	/// - Returns: A row and column index
	public static func cellReference(_ colRow: String) -> (row: Int, col: Int)? {
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
	
	/// Parse the data for row indexes
	/// - Returns: Row string indexes
	public func parse() -> [String.Index] {
		let cp = reader.currentPos
		reader.currentPos = reader.data.startIndex
		var ret: [String.Index] = []
		while !reader.atEnd {
			ret.append(reader.currentPos)
			_ = reader.readRow()
		}
		reader.currentPos = cp
		return ret
	}
	
	/// Retrieve a value for a header key
	/// - Parameters:
	///   - headerName: The name of the header
	///   - defaultValue: Defines the type of the data returned and a default value if the header is missing or the data cannot be converted
	/// - Returns: The value or the default value if not found/convertable
	public func `get`<T>(_ headerName: String, _ defaultValue: T) -> T {
		guard let key = headers.keys.first(where: {$0.localizedStandardCompare(headerName) == .orderedSame}) ?? headers.keys.first(where: {$0.localizedCaseInsensitiveCompare(headerName) == .orderedSame}) else { return defaultValue }
		if currentLine.count > headers[key]! {
			return currentLine[headers[key]!] as? T ?? defaultValue
		}
		return defaultValue
	}
	
	/// Retrieve a value for a column index
	/// - Parameters:
	///   - index: Zero-based index of the column
	///   - defaultValue: Defines the type of the data returned and a default value if the header is missing or the data cannot be converted
	/// - Returns: The value or the default value if not found/convertable
	public func `get`<T>(_ index: Int, _ defaultValue: T) -> T {
		guard (0..<currentLine.count).contains(index) else { return defaultValue }
		return currentLine[index] as? T ?? defaultValue
	}
}

/// A file reader for a CSV. Use CSVFile to read the file - this is moreorless the file processor whereas CSVFile is a friendlier interface
public class CSVFileReader {
	
	/// Initializer with string data
	/// - Parameters:
	///   - data: The string data to process
	///   - currentPos: You can set the current string index of where the data starts within the string data
	///   - encoding: How the data is encoded
	///   - logger: An optional logger
	public init(data: String, currentPos: String.Index? = nil, encoding: String.Encoding? = nil, logger: CSVFileReaderLogDelegate? = nil) {
		self.data = data
		self.currentPos = currentPos ?? data.startIndex
		self.encoding = encoding ?? self.encoding
		self.logger = logger
	}
	
	/// An optional logger
	public var logger: CSVFileReaderLogDelegate? = nil
	
	/// The csv string data
	var data: String
	/// How the csv string data is encoded
	var encoding: String.Encoding = .utf8
	private var logCurrentPosChange = ""
	/// The string index of the current row being processed
	var currentPos: String.Index {
		didSet {
			if !logCurrentPosChange.isEmpty {
				logger?.log("\(logCurrentPosChange): \(oldValue) -> \(currentPos)")
				logCurrentPosChange = ""
			}
		}
	}
	
	/// Is the data exhausted
	public var atEnd: Bool {
		currentPos >= data.endIndex
	}
	
	/// At the end of a row? This is usually false as currentPos will be the next processing row. But during processing this will change depending on whether the string index is at the end of a row or not
	/// - Returns: True/false
	public func atEndOfRow() -> Bool {
		if data.extract(currentPos, 2) == "\r\n" || data.extract(currentPos, 1) == "\n" { return true }
		return atEnd
	}
	
	/// Read the current row as a list of headers
	/// - Returns: Key and column index dictionary. Repeated headers will be overwritten.
	public func readHeaders(indexForUniqueness: Bool = false) -> [String:Int] {
		logger?.log("<< readHeaders() >>")
		currentPos = data.startIndex
		let items = readRow()
		var ret: [String:Int] = [:]
		var repeating: [String:Int] = [:]
		if indexForUniqueness {
			//Get all the header items that have > 1
			items.forEach { item in
				if items.count(where: {$0 == item}) > 1 {
					repeating[item] = 0
				}
			}
		}
		(0..<items.count).forEach { index in
			let key = items[index]
			if repeating.keys.contains(key) {
				ret["\(key)[\(repeating[key]!)]"] = index
				repeating[key]! += 1
			}
			else {
				ret[key] = index
			}
		}
		return ret
	}
	
	/// Reads a data row using the headers.
	/// - Parameter headers: The headers for the CSV.
	/// - Returns: A dictionary of header:value
	public func readDataRow(headers: [String:Int]) -> [String:String] {
		logger?.log("<< readDataLine(headers) >>")
		let items = readRow()
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
	
	/// Read the next row as an array of string items
	/// - Returns: Array of string items
	public func readRow() -> [String] {
		logger?.log("<< readRow() >>")
		var ret: [String] = []
		while !atEndOfRow() {
			ret.append(readNext())
		}
		logger?.log("  - \(ret.count) items read")
		currentPos = data.afterIndex("\n", startingAtIndex: currentPos)
		return ret
	}
	
	/// Reads the next data item (column)
	/// - Parameter startingAt: An optional string index of where to read from. currentPos is default
	/// - Returns: A string data item
	public func readNext(startingAt: String.Index? = nil) -> String {
		guard !atEnd else { return "" }
		guard !atEndOfRow() else {
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
				if !atEndOfRow() {
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

