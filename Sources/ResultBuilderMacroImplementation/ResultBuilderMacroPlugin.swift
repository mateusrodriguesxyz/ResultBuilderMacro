import SwiftCompilerPlugin
@_spi(ExperimentalLanguageFeature) import SwiftSyntaxMacros

@main
struct ResultBuilderMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResultBuilderMacro.self,
    ]
}


