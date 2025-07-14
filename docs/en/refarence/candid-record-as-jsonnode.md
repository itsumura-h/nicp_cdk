# Detailed Design of Candid Record Dynamic Representation in Nim

## Background and Purpose

In the development of Canisters for ICP (Internet Computer), a dynamic value representation is required to handle **Candid**, the data serialization format, in the Nim language. Specifically, Candid's `record` type manages field names with hashed numerical IDs, but developers want to operate intuitively with string keys. Candid also has **diverse data types** such as boolean values, various numbers, strings, arrays, nested records, option types, variant types, and Principal. The goal is to treat these as a **dynamic data structure** in Nim, similar to JSON, and to provide a conversion function to a JSON-like text representation.

This design document, drawing inspiration from Nim's standard library `JsonNode`, designs a dynamic structure (tentatively named `CandidValue` type) that can comprehensively hold and manipulate all Candid types. The focus will be on the following points:

* **Investigation of Nim Standard JsonNode Structure and API:** Understand the mechanism of `JsonNode` for dynamically handling JSON data and use it as a design guideline.
* **Mapping Candid Types to Nim Structures:** Design how each Candid data type (Bool, various numbers, Text, Null, Record, Variant, Option, Principal, Func, Service, etc.) will be represented by types and values in Nim.
* **String Key Access for Record Types:** Design methods for handling Candid record field name hashing and accessing them with string keys in Nim (utilization of hash functions and accessor specifications).
* **Data Structure and Operation API:** Based on the above, detail the design of `CandidValue`'s specific data structure (object variant type) and its operation APIs such as creation, reading, writing, deletion, and JSON conversion. Nim code examples will be used to illustrate actual usage scenarios.

Each item will be described in detail below.

## Nim Standard Library JsonNode Structure and Operations

Nim provides a standard `JsonNode` type for dynamically handling JSON. This `JsonNode` is implemented as an **object variant (an object with a mutable part)**, containing an internal `kind` field that indicates its type. The data stored differs depending on the `kind` value. For example:

* `JNull` (null value)
* `JBool` (boolean value)
* `JInt` (integer value)
* `JFloat` (floating-point value)
* `JString` (string)
* `JArray` (array)
* `JObject` (object / associative array)

The type of `JsonNode` can be obtained with `jsonNode.kind`, and properties are accessed accordingly. In particular, for `JObject`, it internally holds `fields`, an `OrderedTable[string, JsonNode]` (an ordered hash map with string keys and JsonNode values), mapping field names to values. For `JArray`, it internally has `elems: seq[JsonNode]` (a sequence of JsonNode), holding array elements in order. Other primitive types, such as `JBool`, hold a `bool` type value internally, and `JInt` holds an integer value, and so on.

**Main Operations of JsonNode:**
The Nim `json` module defines operators and helpers for intuitive operations.

* **Creation:** Constructors like `newJObject()`, `newJArray()`, `newJInt(n)`, `newJString(s)` are provided. A macro `%*` is also available to construct `JsonNode` from literals, allowing concise JSON literal writing. For example, writing `%* {"element": element, "atomicNumber": atomicNumber}` generates a `JObject` from the given keys and values.

* **Field Access:** For `JObject`, sub-elements can be accessed with `node["keyName"]` index notation. Accessing a non-existent key with `[]` raises an exception. Alternatively, for safe access, using curly braces `node{"keyName"}` returns `nil` if the key doesn't exist. The `contains(node, key)` procedure can also check for key existence.

* **Value Retrieval:** Helpers like `getInt()`, `getFloat()`, `getStr()`, `getBool()` are available to convert the retrieved `JsonNode` to Nim's basic types. For example, `node["age"].getInt()` retrieves an integer value. Overloads that specify a default value and return the default if it doesn't exist are also available.

* **Value Setting:** For `JObject`, fields can be added or updated using assignment statements like `node["keyName"] = newJsonNodeValue`. For arrays, elements can be updated with `node[index] = value`, and child elements can be added with the `add(parent, child)` procedure.

* **Deletion:** `delete(obj, key)` is provided to delete a field from an object, which removes that field with `obj.delete("keyName")`.

* **Stringification:** `JsonNode` can be converted to a JSON string using the `$` operator (`$jsonNode`). In this case, keys are ordered as they were originally, resulting in human-readable JSON text (Nim's implementation preserves object key order using `OrderedTable`).

The design and functionality of `JsonNode` described above are very useful for considering the dynamic representation of Candid values. The next section will discuss how to map Candid data types in Nim.

## Mapping Candid Data Types in Nim Design

This section summarizes the main data types supported by Candid and the policy for their representation in Nim. Candid types are more varied than JSON, and the **dynamic type holder** `CandidValue` (tentative name) must be able to store all of them. 

* **Null Type:** Candid's `null` is a unit type that holds no value. This will be handled in `CandidValue` by creating a `CVNull` (Candid Value Null) type, similar to `JNull` in `JsonNode`. It holds no internal value.

* **Bool Type:** Candid's `bool` is a boolean value. It will be held as Nim's `bool` and represented by the `CVBool` type. The idea is to have `boolVal: bool` internally.

* **Numeric Types:** Candid has **arbitrary-precision integers** (signed/unsigned `Int`, `Nat`), fixed-size integers (`Int8/16/32/64` and `Nat8/16/32/64`), and floating-point numbers (`Float32`, `Float64`). For dynamic structures, it is desirable to handle them as **uniformly as possible without loss of range**. As a design policy:

  * **Arbitrary Precision Integers (`Int`/`Nat`):** Nim's default integer type `int` has 64-bit precision, but Candid's `Int`/`Nat` theoretically have arbitrary size. Therefore, we consider holding them as **multiple-precision integers** (e.g., `BigInt` type) provided by Nim's `bigints` module or similar. In `CandidValue`, for example, the `CVInt` type would have `intVal: BigInt` to hold signed integer values. Similarly, `Nat` (non-negative integers) could also be held as `BigInt`, differing only in lacking a sign. For convenience in design, we will **comprehensively hold `Int`/`Nat` without distinguishing signed/unsigned** in a single `CVInt` type and check the sign if necessary (though care is needed when type information is required).
  * **Fixed-Size Integers:** `Int8`/`Int16` values can also be held as `BigInt` if they are within range. As dynamic values, they will be stored in `CVInt` without regard to size differences and outputted according to bit width during encoding. If necessary, types could be subdivided (e.g., `CVInt32`) to hold Nim's corresponding bit-width types (e.g., `int32`), but this is a trade-off with implementation complexity. In this design, simplicity is prioritized, and integers are for now managed uniformly in `CVInt` (multiple-precision).
  * **Floating-Point Numbers:** `Float32` and `Float64` are single-precision and double-precision floating-point numbers, respectively. These will be held in Nim's `float32` and `float64` types (or simply `float` type). To avoid losing precision in internal representation, they will be managed in **separate types** like `CVFloat32` and `CVFloat64`, each having fields like `float32Val: float32` and `float64Val: float`.

* **Text Type:** Candid's `text` is a UTF-8 string. This can be handled without issues using Nim's `string`. `CandidValue` will have a `CVText` type and internally hold `strVal: string`.

* **Blob Type:** Candid's `blob` is binary data (a synonym for the `vec nat8` type). JSON has no corresponding type, but this design will distinguish it specially. A `CVBlob` type will be created, internally holding data as Nim's `seq[uint8]` (byte sequence) or `array[byte]`. Principal IDs, for example, have binary representations internally, so they are sometimes treated as `blob`. For JSON-like stringification, `blob` could be outputted as a Base64 encoded string or as an array of byte values (details below).

* **Record Type:** Candid's `record` is a struct/associative array, where **field names are mapped to hashed integer IDs** and stored. However, it is more intuitive for developers to handle them with string field names. Similar to `JObject` in Nim's `JsonNode`, `CandidValue` will have a `CVRecord` type, internally holding a map from field names to child `CandidValue`s. Keys will be **strings**, and values will be nested `CandidValue`s. Nim's standard `Table` or `OrderedTable[string, CandidValue]` (for order preservation) will be used. **Internally, key names will be held as is**, but during encoding (serialization), these key strings will be converted to 32-bit integer IDs using a predetermined hash function (details in the next section). Note that collisions of field name hash values within a single record are not allowed by the Candid specification. If different names hypothetically result in the same hash ID, the record type definition itself would be invalid. This property ensures a unique mapping from key string to ID.

* **Variant Type:** Candid's `variant` is a **tagged union type** similar to an enum. It chooses one of multiple tags (cases) and takes a value corresponding to that case (or a case that holds no value). The tag names for `variant` are also internally managed as hashed IDs. `CandidValue` will have a `CVVariant` type, internally holding the selected tag name and the `CandidValue` corresponding to that tag. Specifically, it might have `variantTag: string` and `variantVal: CandidValue`. For cases with no value, `variantVal` can be represented by a `CVNull`-equivalent value (or internally `nil`). Variant tag name to ID conversion will be done using a 32-bit hash function, similar to Record, and used during encoding. When decoding values without type information, variant tags can only be obtained as numbers, but this design **assumes that dynamic values are generally generated with type information**, allowing tag names to be preserved.

* **Option Type:** Candid's `opt T` (option type) represents either having a value of type `T` or no value (None, a concept distinct from `null`). It is essentially a structure similar to `variant { none; some: T }`. `CandidValue` will have a `CVOption` type, internally holding `hasValue: bool` (whether there is a value) and `optVal: CandidValue` (the content if there is a value). For example, if there is no value (None), `hasValue = false` and `optVal` is unused (or `nil`), and if there is a value (Some), `hasValue = true` and `optVal` stores that value. **Note:** Candid's `null` type value and `opt T`'s None are distinguished. When an Option is None, it is desirable for `optVal` to still be able to represent what type `T` is, but this dynamic structure does not hold type information, so the type is lost for None. During encoding, it needs to be handled from context (expected type information), but details are discussed later.

* **Principal Type:** Candid's `principal` is an entity ID identifying a Canister or user. Internally, it is binary data of up to about 29 bytes, and its text representation is a Base32 string (e.g., `aaaaa-aa` format). `CandidValue` will have a `CVPrincipal` type and hold the principal in a type that handles principals in Nim (e.g., `PrincipalId` struct or simply `string` representation). For simplicity, we will assume it is held as a **text representation string** (convert to internal binary if needed). During encoding, this string will be validated and converted to binary form.

* **Func Type:** Candid's `func` is a function reference, represented by a pair `(principal, method_name)`. `principal` is the target Canister, and `method_name` is the function name. This will also be a `CandidValue` of type `CVFunc`, internally holding a tuple or struct of `(principal: PrincipalId, method: string)`. For example, `funcVal: tuple[principal: PrincipalId, method: string]`. The handling of Principal is similar to `CVPrincipal` above, but method names are ordinary strings.

* **Service Type:** `service` is a service (Canister) reference, which may have a principal and an interface type ID. Here, we assume a principal is sufficient and create a `CVService` type holding only `serviceId: PrincipalId` (manage type descriptions separately if needed). It is effectively similar to `CVPrincipal`.

* **Reserved / Empty Types:** Candid has special types `reserved` and `empty`. `reserved` is a top type that matches any value, and `empty` is a bottom type that cannot take any value. These usually do not appear in data retention, but `reserved` may be used to "discard values" during decoding. For dynamic value design, we will not create special types; **`reserved` does not require special handling as it can store any value**, and `empty` does not appear as a dynamic value itself since it holds no value. However, if `reserved` is specified as type information, separate processing may be needed, such as ignoring the value even if stored (this document does not delve deeply into handling type definitions).

With the above mapping, all values expressible in Candid can be held in Nim's `CandidValue`. Next, we will detail the hashing of Record field names and mechanisms for transparently handling them.

## Record Field Name Hashing and String Key Accessors

**Candid Record Structure:** As mentioned, Candid records identify fields by **field ID** (a 32-bit integer) rather than field name. The field ID is typically defined as a hash value calculated from the field name string. The Candid specification does not allow different named fields to have the same ID (hash value) within the same record; if a collision occurs, it is a type definition error. A hash function that outputs a **32-bit result** is used for this, functioning as a unique ID derived from the field name.

The exact specification of the hash function is defined in the Candid interface specification, but it has rules such as "if the field name consists only of digits, that number is considered the ID; otherwise, a SHA-224 based hash trimmed to 32 bits is used" (ref: Candid implementation and DFINITY forum discussions). The important point is that **the same name always yields the same ID**, and **the original name cannot be uniquely retrieved from the ID**. In fact, Candid binary does not contain field names, only IDs, so if there is no type information during decoding, field names cannot be reproduced and are output as numbers. For example, decoding `record { first_name = "John"; age = 24 }` without type information might result in `(record { 2797692922 = "John"; 4846783 = 24 })` with numerical keys.

**Access with String Keys:** In our Nim implementation, developers will manipulate records using **string field names**, and hash conversion will be performed internally as needed. The specific mechanism is as follows:

* `CandidValue`'s `CVRecord` internally holds `fields: OrderedTable[string, CandidValue]`, using **human-readable field name strings as keys**. For example, for the field name `"name"`, the key is also the string `"name"`. Developers also use this key string when accessing the record.

* **Field Addition/Update:** When a developer assigns `rec["fieldName"] = value`, the implementation immediately calculates the 32-bit ID for `"fieldName"` using a hash function. Then, the `value` is stored in the `fields` map with the key `"fieldName"`. Simultaneously, storing the calculated hash ID as metadata for the record can make encoding efficient by avoiding recalculation. For example, internally maintain a `fieldIdMap: Table[string, uint32]` and record `fieldIdMap["fieldName"] = 0xABCD1234` upon addition. For simplicity in design, recalculation is acceptable, but caching should be kept in mind for implementation.

* **Field Retrieval:** When `rec["fieldName"]` is accessed, the implementation simply searches the `fields` table for the key `"fieldName"` and returns the corresponding `CandidValue`. Developers do not need to be aware of hash IDs. Similar to Nim's `JsonNode`, if the key does not exist, a `KeyError` exception is raised. If existence is uncertain, it can be checked with `rec.contains("fieldName")` or an interface like `rec{"fieldName"}` can be provided for safe access, returning `nil` (if not found) or the value.

* **Direct Hash ID Specification:** Developers typically do not directly specify hashed IDs instead of field names. However, for advanced uses where an ID needs to be specified, we could adopt a convention where if the key string is passed in a special format like ` "_{ID}_"`, that ID value is used directly. For example, writing `rec["_42_"]` would access the field with ID=42. This feature is usually unnecessary, but to distinguish numerical keys in JSON text output, keys enclosed in `_..._` will be treated as "numerical IDs".

* **Field Deletion:** `rec.delete("fieldName")` or `delete(rec, "fieldName")` removes the key `"fieldName"` from the map. The internally held hash ID record is also deleted.

**Encoding Process:** When generating Candid binary messages (encoding) from a `CandidValue` structure, the following steps are performed for records:

1. Retrieve each key string from the `fields` map and calculate its 32-bit ID using the hash function (use cached value if available).
2. Sort the fields in **ascending order** of their IDs. This is because Candid records are serialized in ascending order of field IDs.
3. Encode the values of each field in the sorted order (they are described in the type information table in the same ID order).

Thus, values are stored and accessed based on strings, and only during encoding is the hash ID considered. During decoding (binary to structure), if type information is available, the ID is mapped back to the name. This is usually done from name information associated with the type, but if decoded without type information, the key might be temporarily stored as a string in the `"_ {ID} _"` format, and later replaced when the appropriate name is identified.

Through this mechanism, developers can **naturally manipulate records using string field names**, without needing to be aware of the internal hash IDs.

## CandidValue Data Structure and Operation API Design

Based on the above mapping and requirements, this section designs the concrete form of the `CandidValue` type to be implemented in Nim, along with its associated APIs (creation, manipulation, conversion). The basic policy is similar to Nim's `JsonNode`, but differs in supporting Candid-specific types. Pseudo-code is used for explanation.

### Data Structure Definition (Object Variant)

First, `CandidValue` itself is defined as an **object variant**. In Nim, `case` statements can be used to define variant objects. The active fields change based on its `kind` field. An overview of the definition is as follows:

```nim
type
  CandidKind* = enum
    ckNull, ckBool, ckInt, ckFloat32, ckFloat64, ckText, ckBlob,
    ckRecord, ckVariant, ckOption, ckPrincipal, ckFunc, ckService

  CandidValue* = ref object
    case kind*: CandidKind
    of ckNull:
      discard  # Holds no value
    of ckBool:
      boolVal*: bool
    of ckInt:
      intVal*: BigInt           # arbitrary precision integer
      # (Nat also stored as signed; sign checked if necessary)
    of ckFloat32:
      f32Val*: float32
    of ckFloat64:
      f64Val*: float            # Nim's float is 64bit by default
    of ckText:
      strVal*: string
    of ckBlob:
      bytesVal*: seq[uint8]
    of ckRecord:
      fields*: OrderedTable[string, CandidValue]
    of ckVariant:
      variantTag*: string
      variantVal*: CandidValue   # Can be null equivalent if no value
    of ckOption:
      hasValue*: bool
      optVal*: CandidValue      # Unused (can be nil) when hasValue=false
    of ckPrincipal:
      principalId*: string      # text representation of principal (e.g., "aaaaa-aa")
    of ckFunc:
      funcRef*: tuple[principal: string, method: string]
    of ckService:
      serviceId*: string        # Held in the same format as principal
```

Types not included above:

* `reserved` does not require special handling as it can take any type of value. When interpreting a field of `reserved` type, it is considered that any `CandidValue` can actually be stored.
* `empty` does not appear in `CandidValue` as it is a type that holds no value.

This data structure allows a single `CandidValue` to represent any Candid value. `CandidKind` internally has 13 types (members of the enum above), equivalent to JSON's JNull etc. Supplements for each type are provided below.

* `ckNull`: Defined with `discard` as it holds no value. Treated similarly to null in other languages.
* `ckBool`: Nim's `bool` as is.
* `ckInt`: Arbitrary precision integer. `BigInt` refers to Nim's multiple-precision integer type (e.g., from `mpdecimal` or `bigints` modules). If not available, signed 64-bit `int` can be substituted, but with overflow concerns.
* `ckFloat32`/`ckFloat64`: Single-precision and double-precision floats, respectively. Separated into different variants to avoid confusion during storage.
* `ckText`: UTF-8 string. Nim's `string` can hold UTF-8.
* `ckBlob`: Binary. Held as a variable-length byte sequence `seq[uint8]`. Output directly during encoding, and `vec nat8` automatically becomes `ckBlob` during decoding. Note that it is not a string.
* `ckRecord`: Field map. Using `OrderedTable` preserves **field insertion order**. While JSON does not require order preservation, Nim's JsonNode implementation preserves order, and we follow suit. This contributes to stable encoding results and better readability for debugging. During encoding (binary conversion), fields are sorted by ID, not necessarily by insertion order.
* `ckVariant`: Holds the currently selected tag name and its value. If no value, `variantVal` can be `ckNull` or `nil` (the latter requires `variantVal` to be `ref CandidValue`, but for simplicity, `variantVal` is always a non-nil `CandidValue` and `ckNull` is inserted if no value).
* `ckOption`: If `hasValue` is false, it's None; if true, it's Some, holding the actual value in `optVal`. The definition above doesn't explicitly state `optVal` can be `nil`, but in Nim's variant it can be `nil` by default since `optVal` is a `CandidValue` (ref type). For None, `optVal == nil` is fine, or it can be judged by `hasValue`. Here, we explicitly check `hasValue`.
* `ckPrincipal`/`ckService`: Both hold Principal ID as `string`. For `ckService`, if interface descriptors (types) are to be held in the future, add `serviceType: someTypeDescriptor` etc., but this document omits it.
* `ckFunc`: Pair of principal and method name. Principal is a string ID similar to `ckPrincipal`, and method name is a normal function name string.

### Instance Creation and Conversion API

To create `CandidValue`s, **constructor functions** and **utility macros** will be provided. Similar to Nim's standard JSON having `newJObject()`, `%*` macro, etc., the following functions are assumed.

* `newCNull(): CandidValue` – Returns a `CandidValue` representing a Null value.
* `newCBool(b: bool): CandidValue` – Generates from a boolean value.
* `newCInt(i: int|BigInt): CandidValue` – Generates from an integer. Holds appropriately based on type (provide `int` and `BigInt` versions using Nim's overloading).
* `newCFloat32(x: float32): CandidValue` / `newCFloat64(x: float): CandidValue` – Generates from a floating-point number.
* `newCText(s: string): CandidValue` – Generates from text.
* `newCBlob(bytes: seq[uint8]): CandidValue` – Generates from a byte sequence.
* `newCRecord(): CandidValue` – Generates an empty record.
* `newCVariant(tag: string, val: CandidValue): CandidValue` – Generates a Variant with a specified tag and value.
* `newCVariant(tag: string): CandidValue` – Generates a Variant case without a value (internally sets `ckNull` value).
* `newCOption(val: CandidValue): CandidValue` – Generates an Option with a Some value (hasValue=true).
* `newCOptionNone(T: type): CandidValue` – Generates a None of type `T` (hasValue=false, optVal not set).
* `newCPrincipal(text: string): CandidValue` – Generates from a Principal ID string.
* `newCFunc(principal: string, method: string): CandidValue` – Generates a Func reference.
* `newCService(principal: string): CandidValue` – Generates a Service reference.

These functions allow basic values to be generated. Additionally, as a Nim syntax extension, a literal construction macro inspired by JSON's `%*` macro is considered. For example, defining a `%C` macro, writing `%C { "name": "Alice", "age": 30 }` would automatically create a `CandidValue` Record. Nim's `%*` converts object and array literals to `JsonNode`. Similarly implementing a Candid version would allow constructing structures from literals more concisely.

**Example: CandidValue Creation** (Code Example):

```nim
# Example of building a simple record value
var person = newCRecord()
person["name"] = newCText("Alice")
person["age"]  = newCInt(30)
person["isMember"] = newCBool(true)

# Nested fields (sub-records) and arrays
person["address"] = newCRecord()
person["address"]["city"] = newCText("Tokyo")
person["address"]["zip"]  = newCText("100-0001")

person["scores"] = newCArray()              # newCArray is a function that returns an empty array, similar to newCRecord
let scores = person["scores"]
scores.add(newCInt(90))
scores.add(newCInt(85))
scores.add(newCInt(88))

# Variant type field
person["status"] = newCVariant("Active")    # Variant case with no value (tag "Active")
# Option type field
person["nickname"] = newCOptionNone(string) # None of string type (no value)
person["rating"]   = newCOption(newCInt(5)) # Some(5) 
```

This allows intuitive index and method-based manipulation and referencing of values. Helpers like `getInt()` and `getStr()` perform type checks and conversions internally, e.g., converting `ckInt` to Nim's `int` and returning `string` for `ckText`. In implementation, converting `BigInt` to `int` might cause range overflow, in which case an exception will be thrown or higher bits truncated (exception for safety).

### Field/Element Access API

To ensure JSON-like access to `CandidValue`, the following procedures and operators will be provided.

* **Record Key Access:**

  * `proc [](cv: CandidValue; key: string): var CandidValue` – For records (ckRecord), returns a reference to the value of the specified key. Raises `KeyError` if not found.
  * `proc []=(cv: CandidValue; key: string; value: CandidValue)` – Sets a field for a record. Can be used as `cv["foo"] = bar` as in the example above. Internally adds a new key or updates the value for an existing key. If `cv` is not `ckRecord`, it raises an error (for type mismatch detection).
  * `proc contains(cv: CandidValue; key: string): bool` – Checks if a key exists in the record. Returns true if it exists.
  * `proc get(cv: CandidValue; key: string): CandidValue` – Performs safe retrieval. Returns `ckNull` or `nil` if not found, otherwise returns the value. Alternatively, returning Nim's `Option` type is possible, but simplified here. Nim standard provides `node{"key"}` syntax, which can be implemented for custom types via operator overloading (`template `{}`(...)` definition required).

* **Array Index Access:**

  * `proc [](cv: CandidValue; index: int): var CandidValue` – For arrays (ckArray), returns a reference to the element at the specified index. Raises `IndexError` or similar if out of bounds.
  * `proc []=(cv: CandidValue; index: int; value: CandidValue)` – Overwrites an array element. Only valid for existing indices; raises an error or automatically extends for out-of-bounds (error in this case).
  * `proc add(cv: CandidValue; value: CandidValue)` – Adds an element to the end of an array. Implementation is simply `cv.elems.add(value)`.
  * `proc len(cv: CandidValue): int` – Returns array length (can return 0 for non-ckArray types).

* **Option Value Access:**
  Options are not treated specially; developers can check `cv.kind` for `ckOption`, then `cv.hasValue` to decide whether to use `cv.optVal` manually. However, helpers can simplify this. For example:

  * `proc isSome(cv: CandidValue): bool` – Returns true if it's an Option and has a value, false otherwise.
  * `proc getOpt(cv: CandidValue): CandidValue` – Retrieves the value inside an Option. If no value, considers returning a default `CandidValue` (e.g., `ckNull`) or raising an error. Nim's `Option[T]`'s `get()` throws `UnpackDefect` if no value. Following that, an error for None is acceptable.

* **Variant Value Access:**
  Specific helpers for Variant are also considered.

  * `proc variantTag(cv: CandidValue): string` – Returns the tag name of the Variant.
  * `proc variantVal(cv: CandidValue): CandidValue` – Returns the value held by the Variant (e.g., `ckNull` if no value).
    Additionally, a helper to check for a specific tag (e.g., `isCase(cv, tagName: string): bool`) could be useful depending on the use case.

* **Principal, Func, Service Access:**
  Principal is internally just a string, so `cv.principalId` can be used directly for retrieval. However, if Principal has binary form or is objectified for comparison, it needs to be accessed through its methods. Details are omitted here, but conversions like `cv.asPrincipal(): PrincipalId` could be provided. Func and Service are similar.

* **Deletion:**

  * `proc delete(cv: CandidValue; key: string)` – Deletes `key` from a record. Implementation would be `if cv.kind == ckRecord: cv.fields.del(key)`. `delete(cv, index: int)` for arrays is also provided, corresponding to `cv.elems.remove(index)`.

**Example: Field Access and Manipulation** (Code Example):

```nim
# Example of manipulating the person record built above
if person.contains("age"):
  echo person["age"].getInt()           # Get and display 30
person["age"] = newCInt(31)             # Update age
discard person.get("nonexistentField")  # Safe retrieval: returns nil or ckNull if no match

# Accessing array elements
let firstScoreVal = person["scores"][0].getInt()
echo firstScoreVal                      # Display 90
person["scores"][1] = newCInt(95)       # Change second score from 85 to 95
person["scores"].add(newCInt(100))      # Add 100 to the end of the scores array
echo person["scores"].len()            # Get and display length (will be 4)
person["scores"].delete(2)             # Delete the 3rd element (88)

# Using Option and Variant
if not person["nickname"].isSome():
  person["nickname"] = newCOption(newCText("Ali"))  # Set nickname later
let ratingVal = person["rating"].getOpt()           # Gets 5 as Some(5) is present
echo ratingVal.getInt()                            # 5 Display

# Checking Variant case
person["status"] = newCVariant("Inactive")         # Change status to another case
if person["status"].variantTag() == "Inactive":
  echo "Status is now Inactive"
```

This allows intuitive index and method-based manipulation and referencing of values. Helpers like `getInt()` and `getStr()` perform type checks and conversions internally, e.g., converting `ckInt` to Nim's `int` and returning `string` for `ckText`. In implementation, converting `BigInt` to `int` might cause range overflow, in which case an exception will be thrown or higher bits truncated (exception for safety).

### JSON-like Text Conversion

The ability to convert dynamic structures to **JSON-like strings** will also be provided. This helps with debugging, logging, and intuitive understanding of content by developers. Since Candid values have types not found in JSON, the representation will be **similar to JSON**, not fully JSON compatible.

Nim's `JsonNode` provides JSON strings via `$jsonNode` or `echo jsonNode`. Similarly, the `$` operator will be overloaded for `CandidValue` to generate human-readable strings. The conversion policy for each type is as follows.

* **Primitive Types (Null, Bool, Int, Float, Text):** These can be represented like JSON. Null as `null`, Bool as `true`/`false`, Int and Float as numbers (exponential notation if needed), and Text as double-quoted strings. For example, `ckText("Hello")` becomes `"Hello"`, `ckInt(42)` becomes `42`. Very large integers are output as is (BigInt maintains precision, though JavaScript might not handle such large numbers). Floats like `3.14`. No special distinction needed.

* **Blob (Binary Data):** Binary data cannot be directly represented in JSON; it must be converted to a numerical array or string encoded. Candid's text format has `blob "..."` representation, but here, prioritizing JSON-like behavior, we will output **Base64 encoded strings** with a prefix like `"base64:..."` or simply as an array `[byte1, byte2, ...]`.

* **Record:** Equivalent to JSON objects, so **key-value pairs** are arranged as `{ "field1": ..., "field2": ... }`. Original string key names are used, with escaping and quotes as needed. In JSON, keys must always be double-quoted. For example, if a `ckRecord` has fields `name: "Alice", age: 30`, the output will be `{"name": "Alice", "age": 30}`.

  As a special case, handling field names that conflict with other types, such as numeric names or reserved words. In Candid, if a field name consists only of digits, it can be treated as a numeric ID. In this implementation, string keys are generally output as is, but if a "**string contains only digits**", it is converted to **a representation enclosed in underscores**. For example, the key `"42"` (string) would be output as `"_42_"`. This explicitly indicates it's a numeric ID. Also, if a key like `_42_` was actually used internally (in cases where only ID is available during decoding), `"_42_"` will appear in the output. Normal string keys are output with quotes as is.

* **Variant:** Variants have no direct representation in JSON, but representing them as a **single-key object** is intuitive. That is, an object where the selected tag name is the key and its content value is the value. This approach is also adopted in other language bindings; for example, when Candid is exchanged with JavaScript, Variant becomes an object like `{ "TagName": <value> }` (developers provide this form for encoding). Therefore, `ckVariant("Active", ckNull)` would be `{"Active": null}`, and `ckVariant("Error", newCText("msg"))` would be `{"Error": "msg"}`. While there's a risk of tag name collisions (e.g., accidentally matching a Record field name), JSON output is primarily for displaying data content, so no deep distinction is made. Values inside Variants are recursively JSON-converted.

* **Option:** Options are equivalent to `some/none` in Variant, so they can also be represented as a **single-key object** similarly to Variant. Specifically, if there's a value, `{ "some": <value> }`, and if there's no value, `{ "none": null }`. For example, `ckOption(hasValue=false)` would be `{"none": null}`, and `ckOption(hasValue=true, optVal=newCInt(5))` would be `{"some": 5}`. For `none`, there's strictly no type information for the content, but it's displayed as null (the key being `"none"` is the important distinguishing factor).

* **Principal:** Principals are held in text representation (e.g., `aaaaa-bbb...` format), so they are output as **double-quoted strings**. For example, Principal ID `w7x7r-cok77-xa` would be output as `"w7x7r-cok77-xa"`. No special markers are added, but an alternative like `"principal: <ID>"` could be considered if needed. However, simplicity is prioritized here, so it's just a string.

* **Func:** Function references are converted to an object like `{ "principal": "<PRINCIPAL_ID>", "method": "<METHOD_NAME>" }`. Key names are fixed as `principal` and `method`. For example, `ckFunc(principalId="abcd-...", method="foo")` would be `{"principal": "abcd-...", "method": "foo"}`. In some cases, it might be wrapped one level further as `"func": { ... }`, but simplicity is prioritized here.

* **Service:** Service references are just Principal IDs, so the output can be just the principal string, or wrapped like `{"service": "<ID>"}`. To maintain symmetry with Func, `{"principal": "<ID>"}` alone could be fine, but it would be hard to distinguish from Func. Here, since services have fewer special cases, the policy is to simply output the string like Principal.

**Example of JSON-like Output:**
If the `person` record built and manipulated above is stringified using `$person`, the following output is expected.

```javascript
{
  "name": "Alice",
  "age": 31,
  "isMember": true,
  "address": { "city": "Tokyo", "zip": "100-0001" },
  "scores": [ 90, 95, 100 ],
  "status": { "Inactive": null },
  "nickname": { "some": "Ali" },
  "rating": { "some": 5 }
}
```

Each element is represented in a JSON-like manner. `status` is a Variant with tag `Inactive`, so it's `{ "Inactive": null }`. `nickname` and `rating` are Options with Some values, so they are `{ "some": "Ali" }` and `{ "some": 5 }`. If `nickname` or `rating` were None, they would be displayed as `{ "none": null }`.

**Note:** This stringification is for debugging purposes and does not guarantee strict reverse conversion (parsing). Especially, Variant and Option have unique representations not found in standard JSON. Also, note that keys containing `_` or keys like `_123_` have special meaning in interpretation (numerical ID representation). However, this is not an issue for typical data.

### Design Considering Conversion to Candid Messages (Encoding)

Finally, we briefly touch upon the conversion from this structure to Candid binary (IDL message format). `CandidValue` can dynamically hold values, but to send and receive them as Candid messages, they must be encoded with **explicit type information**.

* **Type Information Retention/Inference:** If types are statically determined (e.g., when decoding data received from Rust or Motoko in Nim, and the type is known from the .did file), that type information can be used to assign appropriate names during decoding or convert to binary according to the expected type during encoding. On the other hand, `CandidValue` itself is a value-centric structure and does not completely retain type information. For example, for an empty `ckOption(None)` or an empty `ckArray`, the type of its contents is unknown. Therefore, an **interface that allows passing type information separately as needed** will be provided. For example, design a function like `encodeCandid(cv: CandidValue, typeDesc: CandidType)` that takes a type descriptor (an object representing Candid's type structure) as an argument. The type descriptor would include record field ID to type, inner type of options, element type of vectors, and variant tag types. Referring to this, the values within `cv` are correctly encoded.

  Even without type information, **inference** will be performed as much as possible from `CandidValue`. For example, if an option is Some, the type can be inferred from its contents; if an array has elements, the type can be inferred from them. For Variants, the type of the selected case can be known from the selected value. However, empty arrays, None options, and Variants without values are inferable, so developers need to pass the type.

* **Encoding Process:** Once type information is obtained, it's just a matter of recursively traversing `CandidValue` and constructing the binary. For each type:

  * Primitives (Null, Bool, Number, Text) output corresponding LEB128 integers, floating-point bit sequences, or string byte sequences.
  * Blob outputs length and byte sequence.
  * Record calculates field IDs as described above and encodes child elements in ID order. Child types are also listed in ID order in the type table (type description).
  * Variant hashes the tag name, encodes the corresponding tag ID, and its value. Calculates the index of the tag ID in the type table (variant tags are also sorted) and outputs the tag index as a 1-byte or LEB128 value, followed by the value itself.
  * Option outputs `0x01` (a tag-like value) + value encoding for `some`, or just `0x00` for `none` (Candid's opt is actually represented as 0/1 as a special case of variant).
  * Principal Base32 decodes the text to a byte sequence and outputs its length (1 byte) and data at the beginning.
  * Func encodes principal and string separately (similar to principal + string).
  * Service encodes principal.

While the encoding process itself is beyond the scope of this document, it is important that `CandidValue` is designed to **easily link type information with values**. For example, in Record, **hash IDs can be calculated instantly from key strings**, and in Variant, tag names are retained, similarly. This simplifies encoding implementation. Also, separating `hasValue` and `optVal` in Option simplifies None/Some determination and facilitates compliance with serialization specifications.

Finally, a word about decoding (on reception). It's the reverse of encoding, but since the binary has no field names, type information must be used to assign field names. `CandidValue`を生成する際に型情報があれば、Recordでは正しい名前で`fields`に格納し、Variantでは`variantTag`に名前を入れることができます。型情報がない場合、Recordのキーは`"_<id>_"`形式の文字列にし、Variantタグも`_<id>_`のようにしておく実装になるでしょう。その状態でJSON文字列化すれば`{"_42_": ...}`のように出力され、ハッシュIDであることがわかります。

## Summary

This design proposes `CandidValue` (tentative name), a dynamic data structure for Candid in Nim. It follows the same concept as Nim's standard `JsonNode`, representing all Candid data types with a single variant object, allowing free construction and modification of nested structures. Developers can **access Records with string keys**, similar to JSON. Internally, Candid's specifications for field name hashing and type management are followed, ensuring consistency with encoding/decoding processes.

**Key design points revisited:**

* Implemented as a variant object with `kind` for data type, similar to Nim's JsonNode. Supports primitive types to composite types, using OrderedTable and seq to hold structures.
* Provides cases corresponding to each Candid type, particularly representing types not in JSON like Record, Variant, Option, Principal appropriately. Selects suitable data types for storage (e.g., BigInt, string, tuple) as needed.
* Stores Record field names as strings and has a mechanism to convert them to 32-bit hash IDs in the background. Collisions do not occur by specification. Access is transparent, and conversion to ID only happens during encoding.
* Operation APIs are enriched, similar to JsonNode, providing functions like `[]`, `add`, `delete`, `getXxx`. Enables manipulation of nested data with concise code.
* Has JSON-like string conversion capability, allowing content verification in a human-readable format. Variant and Option are represented as single-key objects, and numeric IDs can be distinguished with special key name (`_..._`) conventions.
* Considers bridging with Candid encoding/decoding, designing for accurate serialization by combining with type information (retaining field names/tag names, managing Option states, etc.). Allows structure construction with names during decoding if type information is used.

Through this proposed `CandidValue` data structure and API, Nim code for ICP Canister development will be able to handle Candid messages flexibly and intuitively. It maintains JSON-like usability while meeting Candid-specific requirements (field IDs, strict types). Based on this design, implementation will proceed, and usability and accuracy will be verified through testing.

**References:**

* Nim official `std/json` documentation (JsonNode structure and operations)
* Nim by Example: JSON usage examples (JsonNode creation and access)
* DFINITY Internet Computer Candid reference and forum information (Record field name hashing and display method)

# ===== Usage Examples and Tests =====

## Naming Conventions and Design Policy

### CandidValue Construction Naming Conventions

This implementation standardizes function naming for explicit CandidValue construction to the **`newC*` pattern**. This offers the following advantages:

1. **Consistency**: All constructors begin with the unified `newC` prefix.
2. **Clarity**: Clearly indicates the creation of a new CandidValue instance.
3. **Alignment with Nim Conventions**: The `new*` pattern is a standard naming convention for object creation in Nim.

#### Supported Construction Functions

**Primitive Types:**
- `newCNull()` - Null value
- `newCBool(value: bool)` - Boolean value
- `newCInt(value: int|BigInt)` - Integer value
- `newCFloat32(value: float32)` - Single-precision floating-point
- `newCFloat64(value: float)` - Double-precision floating-point
- `newCText(value: string)` - Text string
- `newCBlob(value: seq[uint8])` - Binary data

**Structured Types:**
- `newCRecord()` - Empty record
- `newCArray()` - Empty array
- `newCVariant(tag: string, value: CandidValue)` - Variant with value
- `newCVariant(tag: string)` - Variant without value

**Option Type:**
- `newCOption(value: CandidValue)` - Some value
- `newCOptionNone()` - None value
- Standard library `some(value)`, `none(Type)` can also be used.

**Reference Types:**
- `newCPrincipal(id: string)` - Principal reference
- `newCFunc(principal: string, method: string)` - Function reference
- `newCService(principal: string)` - Service reference

### Deprecated Functions

Shorthand functions provided in previous versions have been **deprecated**:

~~`cprincipal()`, `cblob()`, `csome()`, `cnone()`, `cvariant()`, `cfunc()`, `cservice()`, `cnull()`~~

These have been replaced by `newC*` functions or standard library functions.

## %* Macro (candidLit) Usage

The `%*` macro (internally `candidLit` macro) provides a concise way to construct CandidValue from literal syntax, similar to JsonNode's `%*` macro. This macro allows intuitive definition of complex Candid data structures.

### Supported Syntax

#### Primitive Types
```nim
let data = %* {  # Using %* macro
  "name": "Alice",          # Text type
  "age": 30,               # Int type
  "isActive": true,        # Bool type
  "score": 95.5,           # Float64 type
  "nothing": newCNull()    # Null type
}
```

#### Principal Type
```nim
let user = %* {
  "owner": newCPrincipal("aaaaa-aa"),
  "canister": newCPrincipal("w7x7r-cok77-xa")
}
```

#### Blob Type (Binary Data)
```nim
let binary = %* {
  "data": newCBlob(@[1u8, 2u8, 3u8, 4u8, 5u8]),
  "signature": newCBlob(@[0x41u8, 0x42u8, 0x43u8])
}
```

#### Arrays
```nim
let collections = %* {
  "numbers": [1, 2, 3, 4],
  "names": ["Alice", "Bob", "Charlie"],
  "mixed": [42, "text", true]  # Mixing different types is also possible
}
```

#### Option Type (Optional Value)
```nim
let optional = %* {
  "nickname": some("Ali"),        # Some value (standard library)
  "middleName": none(string),     # None value (standard library)
  "rating": some(5)
}
```

#### Variant Type (Variant / Enum Type)
```nim
let variants = %* {
  "status": newCVariant("Active"),                        # Case without value
  "error": newCVariant("Error", newCText("Connection failed")), # Case with value
  "result": newCVariant("Success", newCInt(42))
}
```

#### Func Type and Service Type
```nim
let references = %* {
  "callback": newCFunc("w7x7r-cok77-xa", "handleRequest"),  # Func reference
  "target": newCService("aaaaa-aa")                          # Service reference
}
```

### Example of Complex Nested Structures

```nim
let complexData = %* {
  "user": {
    "id": newCPrincipal("user-123"),
    "profile": {
      "name": "Alice",
      "age": 30,
      "preferences": {
        "theme": newCVariant("Dark"),
        "notifications": some(true)
      }
    },
    "permissions": ["read", "write", "admin"],
    "metadata": newCBlob(@[0x01u8, 0x02u8, 0x03u8])
  },
  "system": {
    "version": "1.0.0",
    "services": [
      newCService("auth-service"),
      newCService("data-service")
    ],
    "callbacks": [
      newCFunc("handler-1", "process"),
      newCFunc("handler-2", "validate")
    ]
  }
}
```

### Dynamic Construction with Variables

```nim
let userName = "Bob"
let userAge = 25
let isAdmin = true
let userData = @[1u8, 2u8, 3u8]

let dynamicData = %* {
  "name": userName,     # Variable reference
  "age": userAge,
  "isAdmin": isAdmin,
  "data": userData      # seq[uint8] automatically becomes Blob type
}
```

### Accessing Data

Constructed CandidValue can be accessed in an intuitive way, similar to JsonNode:

```nim
# Record field access
echo complexData["user"]["profile"]["name"].getStr()  # "Alice"
echo complexData["user"]["profile"]["age"].getInt()   # 30

# Array element access
echo complexData["user"]["permissions"][0].getStr()   # "read"
echo complexData["user"]["permissions"].len()         # 3

# Option value check
if complexData["user"]["profile"]["preferences"]["notifications"].isSome():
  let value = complexData["user"]["profile"]["preferences"]["notifications"].getOpt()
  echo value.getBool()  # true

# Variant tag check
echo complexData["user"]["profile"]["preferences"]["theme"].variantTag()  # "Dark"

# Principal retrieval
echo complexData["user"]["id"].asPrincipal()  # "user-123"

# Func detail retrieval
echo complexData["system"]["callbacks"][0].funcPrincipal()  # "handler-1"
echo complexData["system"]["callbacks"][0].funcMethod()    # "process"
```

### Dynamic Modification

```nim
var mutableData = %* {"initial": "value"}

# Add/update fields
mutableData["newField"] = %* "new value"
mutableData["array"] = %* [1, 2, 3]

# Add elements to array
mutableData["array"].add(%* 4)

# Delete fields
mutableData.delete("initial")
```

### Conversion to JSON-like String

CandidValue can be converted to a JSON-like string using the `$` operator:

```nim
let data = %* {
  "text": "Hello",
  "option": some("value"),
  "variant": newCVariant("Tag", newCText("content")),
  "principal": newCPrincipal("aaaaa-aa")
}

echo $data
# Example Output:
# {
#   "text": "Hello",
#   "option": {"some": "value"},
#   "variant": {"Tag": "content"},
#   "principal": "aaaaa-aa"
# }
```

### Type Safety and Error Handling

Macros perform compile-time type checking, and using unsupported types results in a compile error:

```nim
# This will cause a compile error
# let invalid = %* {"unsupported": someUnsupportedType}
```

During runtime type conversion, accessing an invalid type will raise an exception:

```nim
let data = %* {"number": 42}
try:
  echo data["number"].getStr()  # Attempt to get Int as String
except ValueError as e:
  echo "Type error: ", e.msg   # "Expected Text, got ckInt"
```

### About %* Alias

The `candidLit` macro can be used with the `%*` operator (same syntax as JSON's `%*`):

```nim
# The following are equivalent
let data1 = candidLit {"key": "value"}
let data2 = %* {"key": "value"}  
```

This allows building CandidValue with the same feel as JSON's `%*` macro. For actual use, `%*` is recommended for conciseness.

## Summary

The `%*` macro (candidLit) achieves the following:

1. **Intuitive Syntax**: JsonNode-like literal notation.
2. **Type Safety**: Compile-time type checking.
3. **Comprehensive Type Support**: Supports all Candid types.
4. **Nested Structure Support**: Allows building structures of arbitrary depth.
5. **Variable Support**: Runtime values can also be incorporated.
6. **Error Handling**: Appropriate exception handling.
7. **Unified Naming Convention**: Consistent API with `newC*` pattern.
8. **JSON-Compatible Syntax**: Same writing experience as JSON using the `%*` operator.

### Design Advantages

The new naming convention (`newC*`) provides the following benefits:

- **Consistency with Nim Conventions**: Aligns with `newSeq()`, `newTable()` etc.
- **Clear Intent**: Immediately obvious that a new instance is being created.
- **Improved IntelliSense/Completion**: `newC` functions are grouped together.
- **Maintainability**: Easier to follow rules for future extensions.

Additionally, combining with the standard library's Option type (`some()`, `none()`) allows smooth integration with existing Nim code.

This significantly simplifies and improves the readability of Nim code handling Candid data.

## References 