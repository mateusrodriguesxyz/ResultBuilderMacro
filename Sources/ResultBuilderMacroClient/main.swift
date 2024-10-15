import ResultBuilderMacro

enum E {
    case c1
    case c2
    case c3(Int)
}

extension E {
    static func random() -> E {
        return [.c1, .c2, .c3(Int.random(in: 1...10))].randomElement()!
    }
}



//@_ResuiltBuilder<String>(
//    "buildVirtualFor",
//    "buildVirtualIf",
//    "buildVirtualSwitch",
//    "buildFinalResult"
//)
//func transform() -> String {
//    let a = 5
//    "A"
//    "B"
//    "C"
//    if Bool.random() {
//        "then"
//    } else {
//        "else"
//    }
//    if false {
//        "then"
//    }
//    let x: Int? = 0
//    let y: Int? = 0
//    if let x, let y {
//        "(\(x),\(y))"
//    }
//    for i in 1...10 where i.isMultiple(of: 2) {
//        "\(i)"
//    }
//    switch Int.random(in: 1...5) {
//        case 1:
//            "1"
//        case 2:
//            "2"
//        default:
//            "3...5"
//    }
//    switch E.random() {
//        case .c1:
//            "CASE 1"
//        case .c2:
//            "CASE 2"
//        case .c3(let value):
//            // NOT WORKING WITH `buildEither`
//            "CASE 3 = \(value)"
//    }
//}


func aaa() {
    
    let x: Int? = 0
    let y: Int? = 0
    
    func eval<T>(block: () -> T?) -> T? {
        block()
    }
    
    let _value = eval {
        if Bool.random(), let x, let y  {
            (x, y)
        } else {
            nil
        }
    }
    
    let component = _value.map { (x, y) in
        let component0 = String.buildExpression("(\(x),\(y))")
        return String.buildBlock(component0)
    }
}

@_ResultBuilder<String>()
func transform() -> String {
    "hello"
    let a = 5
    for index in 1...5 {
        "\(index)"
    }
}

print(transform())
