import ResultBuilderMacro

enum StringBuilder: ResultBuilder {
    
    public static func buildBlock(_ components: String...) -> String {
        return components.joined(separator: ",")
    }
    
    public static func buildExpression(_ expression: Int) -> String {
        return "\(expression)"
    }
    
    public static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }
    
    public static func buildEither(first component: String) -> String {
        return component
    }
    
    public static func buildEither(second component: String) -> String {
        return component
    }
    
    public static func buildArray(_ components: [String]) -> String {
        return components.joined(separator: ",")
    }
    
    public static func buildFinalResult(_ component: String) -> String {
        return "RESULT = \(component)"
    }
}

@ResultBuilder<StringBuilder>
func body() -> String {
    "a"
    "b"
    "c"
    if Bool.random() {
        "true"
    } else {
        "false"
    }
    switch Int.random(in: 1...5) {
    case 1:
        "one"
    case 2:
        "two"
    case 3:
        "three"
    default:
        "default"
    }
    for i in 1...5 {
        "\(i)"
    }
}

print(body())
