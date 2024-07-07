import SwiftSyntax
import SwiftSyntaxBuilder
@_spi(ExperimentalLanguageFeature) import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ResultBuilderMacroImplementation)
@_spi(ExperimentalLanguageFeature) import ResultBuilderMacroImplementation

let testMacros: [String: Macro.Type] = [
    "ResultBuilder": ResultBuilderMacro.self,
]
#endif

final class ResultBuilderMacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(ResultBuilderMacroImplementation)
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
}
