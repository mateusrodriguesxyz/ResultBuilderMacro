@attached(body)
public macro ResultBuilder<T: ResultBuilder>() = #externalMacro(module: "ResultBuilderMacroImplementation", type: "ResultBuilderMacro")

public protocol ResultBuilder {
    associatedtype Component
    static func buildBlock(_ components: Component...) -> Component
}

extension ResultBuilder {
    public static func buildExpression(_ expression: Component) -> Component { expression }
    public static func buildFinalResult<T>(_ component: T) -> T { component }
}


@attached(body)
public macro _ResultBuilder<T>(_ methods: String...) = #externalMacro(module: "ResultBuilderMacroImplementation", type: "TransformBodyMacro")
