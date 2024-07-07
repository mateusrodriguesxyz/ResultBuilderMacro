@attached(body)
public macro ResultBuilder<T: ResultBuilder>() = #externalMacro(module: "ResultBuilderMacroImplementation", type: "ResultBuilderMacro")

public protocol ResultBuilder { }

extension ResultBuilder {
    public static func buildExpression<T>(_ expression: T) -> T { expression }
    public static func buildFinalResult<T>(_ component: T) -> T { component }
}
