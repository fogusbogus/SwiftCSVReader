import Testing
@testable import CSVReader

func csv() -> String {
	return "Head1, head2,head3,\"Head 4\",HEAD5,'heading \"6\"'\n1,2,3,Four,5.24"
}

@Test func HeadersReadCorrectly() async throws {
	let csv = CSVFileReader(data: csv())
	let headers = csv.readHeaders()
	#expect(headers.keys.contains("Head1"))
	#expect(headers.keys.contains("head2"))
	#expect(headers.keys.contains("head3"))
	#expect(headers.keys.contains("Head 4"))
	#expect(headers.keys.contains("HEAD5"))
	#expect(headers.keys.contains("heading \"6\""))
	
	#expect(headers.valueOf(key: "Head1") == 0)
	#expect(headers.valueOf(key: "Head2") == 1)
	#expect(headers.valueOf(key: "Head3") == 2)
	#expect(headers.valueOf(key: "head 4") == 3)
	#expect(headers.valueOf(key: "head5") == 4)
	#expect(headers.valueOf(key: "heading \"6\"") == 5)
	print(headers.keys)
}

@Test func headersRepeatingOverwrite() async throws {
	let csv = CSVFileReader(data: "H1,!,H2,!,H3,!")
	let headers = csv.readHeaders(indexForUniqueness: false)
	#expect(headers.count == 4)
}

@Test func headersRepeatingIndexes() async throws {
	let csv = CSVFileReader(data: "H1,!,H2,!,H3,!")
	let headers = csv.readHeaders(indexForUniqueness: true)
	#expect(headers.count == 6)
}
