import Foundation

// MARK: - Cell types

enum XLSXCell {
    case empty
    case string(String)
    case number(Double)
    case bold(String)
}

// MARK: - Sheet model

struct XLSXSheet {
    let name: String
    var rows: [[XLSXCell]]
}

// MARK: - Writer

enum XLSXWriter {

    enum XLSXError: Error {
        case zipFailed(Int32)
        case missingOutput
    }

    static func write(sheets: [XLSXSheet], to destination: URL) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Collect all unique strings across all sheets for the shared-string table
        var stringTable: [String] = []
        var stringIndex: [String: Int] = [:]

        func intern(_ s: String) -> Int {
            if let idx = stringIndex[s] { return idx }
            let idx = stringTable.count
            stringTable.append(s)
            stringIndex[s] = idx
            return idx
        }

        // Pre-pass to build string table (bold strings too)
        for sheet in sheets {
            for row in sheet.rows {
                for cell in row {
                    switch cell {
                    case .string(let s), .bold(let s): _ = intern(s)
                    default: break
                    }
                }
            }
        }

        // ---- [Content_Types].xml ----
        var ctParts = sheets.enumerated().map { i, _ in
            "<Override PartName=\"/xl/worksheets/sheet\(i+1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }.joined()
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          \(ctParts)
        </Types>
        """
        try write(contentTypes, to: tmp.appendingPathComponent("[Content_Types].xml"))

        // ---- _rels/.rels ----
        let relsDir = tmp.appendingPathComponent("_rels", isDirectory: true)
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        try write(rootRels, to: relsDir.appendingPathComponent(".rels"))

        // ---- xl/ ----
        let xl = tmp.appendingPathComponent("xl", isDirectory: true)
        try FileManager.default.createDirectory(at: xl, withIntermediateDirectories: true)

        // ---- xl/workbook.xml ----
        let sheetRefs = sheets.enumerated().map { i, s in
            "<sheet name=\"\(xmlEscape(s.name))\" sheetId=\"\(i+1)\" r:id=\"rId\(i+2)\"/>"
        }.joined()
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>\(sheetRefs)</sheets>
        </workbook>
        """
        try write(workbook, to: xl.appendingPathComponent("workbook.xml"))

        // ---- xl/_rels/workbook.xml.rels ----
        let xlRels = xl.appendingPathComponent("_rels", isDirectory: true)
        try FileManager.default.createDirectory(at: xlRels, withIntermediateDirectories: true)
        var wbRelsContent = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
          <Relationship Id="rId\(sheets.count + 2)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        """
        for (i, _) in sheets.enumerated() {
            wbRelsContent += "\n  <Relationship Id=\"rId\(i+2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i+1).xml\"/>"
        }
        wbRelsContent += "\n</Relationships>"
        try write(wbRelsContent, to: xlRels.appendingPathComponent("workbook.xml.rels"))

        // ---- xl/sharedStrings.xml ----
        let ssItems = stringTable.map { s in
            "<si><t xml:space=\"preserve\">\(xmlEscape(s))</t></si>"
        }.joined()
        let sharedStrings = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(stringTable.count)" uniqueCount="\(stringTable.count)">
        \(ssItems)
        </sst>
        """
        try write(sharedStrings, to: xl.appendingPathComponent("sharedStrings.xml"))

        // ---- xl/styles.xml ----
        // styleIndex 0 = normal, styleIndex 1 = bold
        let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
        </styleSheet>
        """
        try write(styles, to: xl.appendingPathComponent("styles.xml"))

        // ---- xl/worksheets/ ----
        let wsDir = xl.appendingPathComponent("worksheets", isDirectory: true)
        try FileManager.default.createDirectory(at: wsDir, withIntermediateDirectories: true)

        for (sheetIdx, sheet) in sheets.enumerated() {
            var rowsXML = ""
            for (rowIdx, row) in sheet.rows.enumerated() {
                let rowNum = rowIdx + 1
                var cellsXML = ""
                var colIdx = 0
                for cell in row {
                    let colLetter = columnLetter(colIdx)
                    let cellRef = "\(colLetter)\(rowNum)"
                    switch cell {
                    case .empty:
                        break
                    case .string(let s):
                        let si = intern(s)
                        cellsXML += "<c r=\"\(cellRef)\" t=\"s\"><v>\(si)</v></c>"
                    case .bold(let s):
                        let si = intern(s)
                        cellsXML += "<c r=\"\(cellRef)\" t=\"s\" s=\"1\"><v>\(si)</v></c>"
                    case .number(let n):
                        cellsXML += "<c r=\"\(cellRef)\"><v>\(n)</v></c>"
                    }
                    colIdx += 1
                }
                if !cellsXML.isEmpty {
                    rowsXML += "<row r=\"\(rowNum)\">\(cellsXML)</row>"
                }
            }
            let wsXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>\(rowsXML)</sheetData>
            </worksheet>
            """
            try write(wsXML, to: wsDir.appendingPathComponent("sheet\(sheetIdx+1).xml"))
        }

        // ---- Zip into .xlsx ----
        let outputURL = tmp.appendingPathComponent("output.xlsx")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-X", outputURL.path, "."]
        process.currentDirectoryURL = tmp
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw XLSXError.zipFailed(process.terminationStatus)
        }
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw XLSXError.missingOutput
        }

        // Move to destination
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: outputURL, to: destination)
    }

    // MARK: - Helpers

    private static func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func columnLetter(_ index: Int) -> String {
        var n = index
        var result = ""
        repeat {
            result = String(UnicodeScalar(65 + (n % 26))!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }
}
