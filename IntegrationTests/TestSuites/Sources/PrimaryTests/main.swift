import JavaScriptKit

try test("Literal Conversion") {
    let global = JSObject.global
    let inputs: [JSValue] = [
        .boolean(true),
        .boolean(false),
        .string("foobar"),
        .string("👨‍👩‍👧‍👧 Family Emoji"),
        .number(0),
        .number(Double(Int32.max)),
        .number(Double(Int32.min)),
        .number(Double.infinity),
        .number(Double.nan),
        .null,
        .undefined,
    ]
    for (index, input) in inputs.enumerated() {
        let prop = "prop_\(index)"
        setJSValue(this: global, name: prop, value: input)
        let got = getJSValue(this: global, name: prop)
        switch (got, input) {
        case let (.number(lhs), .number(rhs)):
            // Compare bitPattern because nan == nan is always false
            try expectEqual(lhs.bitPattern, rhs.bitPattern)
        default:
            try expectEqual(got, input)
        }
    }
}

try test("Object Conversion") {
    // Notes: globalObject1 is defined in JavaScript environment
    //
    // ```js
    // global.globalObject1 = {
    //   "prop_1": {
    //     "nested_prop": 1,
    //   },
    //   "prop_2": 2,
    //   "prop_3": true,
    //   "prop_4": [
    //     3, 4, "str_elm_1", 5,
    //   ],
    //   ...
    // }
    // ```
    //

    let globalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1Ref = try expectObject(globalObject1)
    let prop_1 = getJSValue(this: globalObject1Ref, name: "prop_1")
    let prop_1Ref = try expectObject(prop_1)
    let nested_prop = getJSValue(this: prop_1Ref, name: "nested_prop")
    try expectEqual(nested_prop, .number(1))
    let prop_2 = getJSValue(this: globalObject1Ref, name: "prop_2")
    try expectEqual(prop_2, .number(2))
    let prop_3 = getJSValue(this: globalObject1Ref, name: "prop_3")
    try expectEqual(prop_3, .boolean(true))
    let prop_4 = getJSValue(this: globalObject1Ref, name: "prop_4")
    let prop_4Array = try expectObject(prop_4)
    let expectedProp_4: [JSValue] = [
        .number(3), .number(4), .string("str_elm_1"), .null, .undefined, .number(5),
    ]
    for (index, expectedElement) in expectedProp_4.enumerated() {
        let actualElement = getJSValue(this: prop_4Array, index: Int32(index))
        try expectEqual(actualElement, expectedElement)
    }

    try expectEqual(getJSValue(this: globalObject1Ref, name: "undefined_prop"), .undefined)
}

try test("Value Construction") {
    let globalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1Ref = try expectObject(globalObject1)
    let prop_2 = getJSValue(this: globalObject1Ref, name: "prop_2")
    try expectEqual(Int.construct(from: prop_2), 2)
    let prop_3 = getJSValue(this: globalObject1Ref, name: "prop_3")
    try expectEqual(Bool.construct(from: prop_3), true)
    let prop_7 = getJSValue(this: globalObject1Ref, name: "prop_7")
    try expectEqual(Double.construct(from: prop_7), 3.14)
    try expectEqual(Float.construct(from: prop_7), 3.14)
}

try test("Array Iterator") {
    let globalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1Ref = try expectObject(globalObject1)
    let prop_4 = getJSValue(this: globalObject1Ref, name: "prop_4")
    let array1 = try expectArray(prop_4)
    let expectedProp_4: [JSValue] = [
        .number(3), .number(4), .string("str_elm_1"), .null, .undefined, .number(5),
    ]
    try expectEqual(Array(array1), expectedProp_4)

    // Ensure that iterator skips empty hole as JavaScript does.
    let prop_8 = getJSValue(this: globalObject1Ref, name: "prop_8")
    let array2 = try expectArray(prop_8)
    let expectedProp_8: [JSValue] = [0, 2, 3, 6]
    try expectEqual(Array(array2), expectedProp_8)
}

try test("Array RandomAccessCollection") {
    let globalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1Ref = try expectObject(globalObject1)
    let prop_4 = getJSValue(this: globalObject1Ref, name: "prop_4")
    let array1 = try expectArray(prop_4)
    let expectedProp_4: [JSValue] = [
        .number(3), .number(4), .string("str_elm_1"), .null, .undefined, .number(5),
    ]
    try expectEqual([array1[0], array1[1], array1[2], array1[3], array1[4], array1[5]], expectedProp_4)

    // Ensure that subscript can access empty hole
    let prop_8 = getJSValue(this: globalObject1Ref, name: "prop_8")
    let array2 = try expectArray(prop_8)
    let expectedProp_8: [JSValue] = [
        0, .undefined, 2, 3, .undefined, .undefined, 6
    ]
    try expectEqual([array2[0], array2[1], array2[2], array2[3], array2[4], array2[5], array2[6]], expectedProp_8)
}

try test("Value Decoder") {
    struct GlobalObject1: Codable {
        struct Prop1: Codable {
            let nested_prop: Int
        }

        let prop_1: Prop1
        let prop_2: Int
        let prop_3: Bool
        let prop_7: Float
    }
    let decoder = JSValueDecoder()
    let rawGlobalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1 = try decoder.decode(GlobalObject1.self, from: rawGlobalObject1)
    try expectEqual(globalObject1.prop_1.nested_prop, 1)
    try expectEqual(globalObject1.prop_2, 2)
    try expectEqual(globalObject1.prop_3, true)
    try expectEqual(globalObject1.prop_7, 3.14)
}

try test("Function Call") {
    // Notes: globalObject1 is defined in JavaScript environment
    //
    // ```js
    // global.globalObject1 = {
    //   ...
    //   "prop_5": {
    //     "func1": function () { return },
    //     "func2": function () { return 1 },
    //     "func3": function (n) { return n * 2 },
    //     "func4": function (a, b, c) { return a + b + c },
    //     "func5": function (x) { return "Hello, " + x },
    //     "func6": function (c, a, b) {
    //       if (c) { return a } else { return b }
    //     },
    //   }
    //   ...
    // }
    // ```
    //

    // Notes: If the size of `RawJSValue` is updated, these test suites will fail.
    let globalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1Ref = try expectObject(globalObject1)
    let prop_5 = getJSValue(this: globalObject1Ref, name: "prop_5")
    let prop_5Ref = try expectObject(prop_5)

    let func1 = try expectFunction(getJSValue(this: prop_5Ref, name: "func1"))
    try expectEqual(func1(), .undefined)
    let func2 = try expectFunction(getJSValue(this: prop_5Ref, name: "func2"))
    try expectEqual(func2(), .number(1))
    let func3 = try expectFunction(getJSValue(this: prop_5Ref, name: "func3"))
    try expectEqual(func3(2), .number(4))
    let func4 = try expectFunction(getJSValue(this: prop_5Ref, name: "func4"))
    try expectEqual(func4(2, 3, 4), .number(9))
    try expectEqual(func4(2, 3, 4, 5), .number(9))
    let func5 = try expectFunction(getJSValue(this: prop_5Ref, name: "func5"))
    try expectEqual(func5("World!"), .string("Hello, World!"))
    let func6 = try expectFunction(getJSValue(this: prop_5Ref, name: "func6"))
    try expectEqual(func6(true, 1, 2), .number(1))
    try expectEqual(func6(false, 1, 2), .number(2))
    try expectEqual(func6(true, "OK", 2), .string("OK"))
}

try test("Host Function Registration") {
    // ```js
    // global.globalObject1 = {
    //   ...
    //   "prop_6": {
    //     "call_host_1": function() {
    //       return global.globalObject1.prop_6.host_func_1()
    //     }
    //   }
    // }
    // ```
    let globalObject1 = getJSValue(this: .global, name: "globalObject1")
    let globalObject1Ref = try expectObject(globalObject1)
    let prop_6 = getJSValue(this: globalObject1Ref, name: "prop_6")
    let prop_6Ref = try expectObject(prop_6)

    var isHostFunc1Called = false
    let hostFunc1 = JSClosure { (_) -> JSValue in
        isHostFunc1Called = true
        return .number(1)
    }

    setJSValue(this: prop_6Ref, name: "host_func_1", value: .function(hostFunc1))

    let call_host_1 = getJSValue(this: prop_6Ref, name: "call_host_1")
    let call_host_1Func = try expectFunction(call_host_1)
    try expectEqual(call_host_1Func(), .number(1))
    try expectEqual(isHostFunc1Called, true)

    hostFunc1.release()

    let hostFunc2 = JSClosure { (arguments) -> JSValue in
        do {
            let input = try expectNumber(arguments[0])
            return .number(input * 2)
        } catch {
            return .string(String(describing: error))
        }
    }

    try expectEqual(hostFunc2(3), .number(6))
    _ = try expectString(hostFunc2(true))
    hostFunc2.release()
}

try test("New Object Construction") {
    // ```js
    // global.Animal = function(name, age, isCat) {
    //   this.name = name
    //   this.age = age
    //   this.bark = () => {
    //     return isCat ? "nyan" : "wan"
    //   }
    // }
    // ```
    let objectConstructor = try expectFunction(getJSValue(this: .global, name: "Animal"))
    let cat1 = objectConstructor.new("Tama", 3, true)
    try expectEqual(getJSValue(this: cat1, name: "name"), .string("Tama"))
    try expectEqual(getJSValue(this: cat1, name: "age"), .number(3))
    try expectEqual(cat1.isInstanceOf(objectConstructor), true)
    try expectEqual(cat1.isInstanceOf(try expectFunction(getJSValue(this: .global, name: "Array"))), false)
    let cat1Bark = try expectFunction(getJSValue(this: cat1, name: "bark"))
    try expectEqual(cat1Bark(), .string("nyan"))

    let dog1 = objectConstructor.new("Pochi", 3, false)
    let dog1Bark = try expectFunction(getJSValue(this: dog1, name: "bark"))
    try expectEqual(dog1Bark(), .string("wan"))
}

try test("Call Function With This") {
    // ```js
    // global.Animal = function(name, age, isCat) {
    //   this.name = name
    //   this.age = age
    //   this.bark = () => {
    //     return isCat ? "nyan" : "wan"
    //   }
    //   this.isCat = isCat
    //   this.getIsCat = function() {
    //     return this.isCat
    //   }
    // }
    // ```
    let objectConstructor = try expectFunction(getJSValue(this: .global, name: "Animal"))
    let cat1 = objectConstructor.new("Tama", 3, true)
    let getIsCat = try expectFunction(getJSValue(this: cat1, name: "getIsCat"))

    // Direct call without this
    try expectEqual(getIsCat(), .undefined)

    // Call with this
    let gotIsCat = getIsCat(this: cat1)
    try expectEqual(gotIsCat, .boolean(true))
}

try test("Object Conversion") {
    let array1 = [1, 2, 3]
    let jsArray1 = array1.jsValue().object!
    try expectEqual(jsArray1.length, .number(3))
    try expectEqual(jsArray1[0], .number(1))
    try expectEqual(jsArray1[1], .number(2))
    try expectEqual(jsArray1[2], .number(3))

    let array2: [JSValueConvertible] = [1, "str", false]
    let jsArray2 = array2.jsValue().object!
    try expectEqual(jsArray2.length, .number(3))
    try expectEqual(jsArray2[0], .number(1))
    try expectEqual(jsArray2[1], .string("str"))
    try expectEqual(jsArray2[2], .boolean(false))
    _ = jsArray2.push!(5)
    try expectEqual(jsArray2.length, .number(4))
    _ = jsArray2.push!(jsArray1)

    try expectEqual(jsArray2[4], .object(jsArray1))

    let dict1: [String: JSValueConvertible] = [
        "prop1": 1,
        "prop2": "foo",
    ]
    let jsDict1 = dict1.jsValue().object!
    try expectEqual(jsDict1.prop1, .number(1))
    try expectEqual(jsDict1.prop2, .string("foo"))
}

try test("ObjectRef Lifetime") {
    // ```js
    // global.globalObject1 = {
    //   "prop_1": {
    //     "nested_prop": 1,
    //   },
    //   "prop_2": 2,
    //   "prop_3": true,
    //   "prop_4": [
    //     3, 4, "str_elm_1", 5,
    //   ],
    //   ...
    // }
    // ```

    let identity = JSClosure { $0[0] }
    let ref1 = getJSValue(this: .global, name: "globalObject1").object!
    let ref2 = identity(ref1).object!
    try expectEqual(ref1.prop_2, .number(2))
    try expectEqual(ref2.prop_2, .number(2))
    identity.release()
}

func closureScope() -> ObjectIdentifier {
    let closure = JSClosure { _ in .undefined }
    let result = ObjectIdentifier(closure)
    closure.release()
    return result
}

try test("Closure Identifiers") {
    let oid1 = closureScope()
    let oid2 = closureScope()
    try expectEqual(oid1, oid2)
}

func checkArray<T>(_ array: [T]) throws where T: TypedArrayElement {
    try expectEqual(toString(JSTypedArray(array).jsValue().object!), jsStringify(array))
}

func toString<T: JSObject>(_ object: T) -> String {
    return object.toString!().string!
}

func jsStringify(_ array: [Any]) -> String {
    array.map({ String(describing: $0) }).joined(separator: ",")
}

try test("TypedArray") {
    let numbers = [UInt8](0 ... 255)
    let typedArray = JSTypedArray(numbers)
    try expectEqual(typedArray[12], 12)

    try checkArray([0, .max, 127, 1] as [UInt8])
    try checkArray([0, 1, .max, .min, -1] as [Int8])

    try checkArray([0, .max, 255, 1] as [UInt16])
    try checkArray([0, 1, .max, .min, -1] as [Int16])

    try checkArray([0, .max, 255, 1] as [UInt32])
    try checkArray([0, 1, .max, .min, -1] as [Int32])

    try checkArray([0, .max, 255, 1] as [UInt])
    try checkArray([0, 1, .max, .min, -1] as [Int])

    let float32Array: [Float32] = [0, 1, .pi, .greatestFiniteMagnitude, .infinity, .leastNonzeroMagnitude, .leastNormalMagnitude, 42]
    let jsFloat32Array = JSTypedArray(float32Array)
    for (i, num) in float32Array.enumerated() {
        try expectEqual(num, jsFloat32Array[i])
    }

    let float64Array: [Float64] = [0, 1, .pi, .greatestFiniteMagnitude, .infinity, .leastNonzeroMagnitude, .leastNormalMagnitude, 42]
    let jsFloat64Array = JSTypedArray(float64Array)
    for (i, num) in float64Array.enumerated() {
        try expectEqual(num, jsFloat64Array[i])
    }
}

try test("TypedArray_Mutation") {
    let array = JSTypedArray<Int>(length: 100)
    for i in 0..<100 {
        array[i] = i
    }
    for i in 0..<100 {
        try expectEqual(i, array[i])
    }
    try expectEqual(toString(array.jsValue().object!), jsStringify(Array(0..<100)))
}

try test("Date") {
    let date1Milliseconds = JSDate.now()
    let date1 = JSDate(millisecondsSinceEpoch: date1Milliseconds)
    let date2 = JSDate(millisecondsSinceEpoch: date1.valueOf())

    try expectEqual(date1.valueOf(), date2.valueOf())
    try expectEqual(date1.fullYear, date2.fullYear)
    try expectEqual(date1.month, date2.month)
    try expectEqual(date1.date, date2.date)
    try expectEqual(date1.day, date2.day)
    try expectEqual(date1.hours, date2.hours)
    try expectEqual(date1.minutes, date2.minutes)
    try expectEqual(date1.seconds, date2.seconds)
    try expectEqual(date1.milliseconds, date2.milliseconds)
    try expectEqual(date1.utcFullYear, date2.utcFullYear)
    try expectEqual(date1.utcMonth, date2.utcMonth)
    try expectEqual(date1.utcDate, date2.utcDate)
    try expectEqual(date1.utcDay, date2.utcDay)
    try expectEqual(date1.utcHours, date2.utcHours)
    try expectEqual(date1.utcMinutes, date2.utcMinutes)
    try expectEqual(date1.utcSeconds, date2.utcSeconds)
    try expectEqual(date1.utcMilliseconds, date2.utcMilliseconds)
    try expectEqual(date1, date2)

    let date3 = JSDate(millisecondsSinceEpoch: 0)
    try expectEqual(date3.valueOf(), 0)
    try expectEqual(date3.utcFullYear, 1970)
    try expectEqual(date3.utcMonth, 0)
    try expectEqual(date3.utcDate, 1)
    // the epoch date was on Friday
    try expectEqual(date3.utcDay, 4)
    try expectEqual(date3.utcHours, 0)
    try expectEqual(date3.utcMinutes, 0)
    try expectEqual(date3.utcSeconds, 0)
    try expectEqual(date3.utcMilliseconds, 0)
    try expectEqual(date3.toISOString(), "1970-01-01T00:00:00.000Z")

    try expectEqual(date3 < date1, true)
}

// make the timers global to prevent early deallocation
var timeout: JSTimer?
var interval: JSTimer?

try test("Timer") {
    let start = JSDate().valueOf()
    let timeoutMilliseconds = 5.0

    timeout = JSTimer(millisecondsDelay: timeoutMilliseconds, isRepeating: false) {
        // verify that at least `timeoutMilliseconds` passed since the `timeout` timer started
        try! expectEqual(start + timeoutMilliseconds <= JSDate().valueOf(), true)
    }

    var count = 0.0
    let maxCount = 5.0
    interval = JSTimer(millisecondsDelay: 5, isRepeating: true) {
        // verify that at least `timeoutMilliseconds * count` passed since the `timeout` 
        // timer started
        try! expectEqual(start + timeoutMilliseconds * count <= JSDate().valueOf(), true)

        guard count < maxCount else {
            // stop the timer after `maxCount` reached
            interval = nil
            return
        }

        count += 1
    }
}

try test("Error") {
    let message = "test error"
    let error = JSError(message: message)
    try expectEqual(error.name, "Error")
    try expectEqual(error.message, message)
    try expectEqual(error.description, "Error: test error")
    try expectEqual(error.stack?.isEmpty, false)
}