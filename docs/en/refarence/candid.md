# Candid Encoder/Decoder Implementation Detailed Design

## Introduction: Candid and ICP Canister Communication Overview

Candid is an IDL (Interface Description Language) for defining and serializing interfaces between smart contracts (canisters) on the Internet Computer (ICP) and the external world. A Candid message always begins with a 4-byte prefix called the **magic number** `DIDL`, followed by three parts: "type table", "type sequence", and "value sequence". This design document presents a detailed design for implementing Candid encoding/decoding processes in Nim language, enabling communication with ICP canisters, based on the Candid specification. It carefully explains each step, including handling various data types, LEB128 encoding, type table construction, and mutual conversion with text format.

## Candid Type System and All Supported Data Types

This section organizes all types supported by Candid and their classifications. Candid types are broadly divided into **primitive types** and **composite types**. For the Nim implementation, we will prepare data structures to represent each of these types, along with encoding and decoding logic.

### Primitive Types

Primitive types are built-in types that represent complete values themselves. The following are defined as primitive types in Candid (hexadecimal notation in parentheses indicates the internal type code in Candid):

*   **null (0x7F)** – A single value type that holds no value. In Candid, it can only take the concrete value `null`.
*   **bool (0x7E)** – Boolean type. Takes two values: `true` or `false`.
*   **text (0x71)** – Text string type. UTF-8 encoded string as serialization.
*   **nat (0x7D)** and **int (0x7C)** – Arbitrary-precision non-negative integers (nat) and signed integers (int). No size limit, handles large values (see LEB128 below for details).
*   **nat8 (0x7B)**, **nat16 (0x7A)**, **nat32 (0x79)**, **nat64 (0x78)** – Fixed-bit-width unsigned integer types (8, 16, 32, 64 bits). Represent non-negative integers within their range, encoded as fixed-length little-endian byte sequences.
*   **int8 (0x77)**, **int16 (0x76)**, **int32 (0x75)**, **int64 (0x74)** – Fixed-bit-width signed integer types (8, 16, 32, 64 bits). Value encoding is fixed-length little-endian (e.g., `int32` is 4 bytes, `int64` is 8 bytes).
*   **float32 (0x73)**, **float64 (0x72)** – 32-bit single-precision and 64-bit double-precision floating-point types. Encoded as little-endian byte sequences in IEEE 754 format.
*   **principal (0x68)** – Type representing a principal (identity). This is an ID identifying users and canisters on ICP. In binary representation, it is a variable-length byte sequence, with the byte length at the beginning followed by the identifier data (a custom format including CRC32 etc. is used for identifiers, but this design will also consider using existing libraries).
*   **reserved (0x70)** – Reserved type. A special "top type" that any type of value can conform to (used by the receiver to ignore fields). Actual value encoding follows the recipient's primitive type, but if received as this type during decoding, the value is discarded or ignored.
*   **empty (0x6F)** – Empty type. A "bottom type" that holds no value at all, meaning that **nothing should be sent** to a location expecting this type. `empty` is typically used to indicate values that cannot appear (e.g., `vec empty` is treated as a vector type that absolutely has no elements, and its length is always 0).

For the above primitive types, Nim will prepare corresponding types or classes as follows:

*   `bool` maps to Nim's built-in bool, represented by `true`/`false`.
*   Text is held in Nim's `string` type (before UTF-8 encoding).
*   Variable-length `nat`/`int` are held in Nim's `BigInt` or `BiggestInt` (arbitrary-precision integers) and processed with LEB128 encoding/decoding.
*   Fixed-size numbers (nat8 etc.) are held in Nim's corresponding bit-width integers (`uint8`,`uint16` etc. / `int8`,`int16` etc.).
*   Floating-point numbers are held in Nim's `float32`/`float64`.
*   `principal` is treated as a byte sequence (e.g., `array[byte]` or Nim's `openArray[byte]`) or a dedicated struct, and mutual conversion logic with text representation (e.g., `aaaaa-aa` format) will be provided separately.
*   `reserved` and `empty` are handled specially and thus do not have direct value representations in Nim. **`reserved`** is treated as a "type compatible with any type"; during decoding, values are discarded, or processed as `nil` or an Optional type for "unused values." **`empty`** signifies an **inconsistency** (sender sent a value but receiver defines it as empty) when it appears during decoding, so it is detected as an error during decoding.

※ **Important:** According to the Candid specification, primitive and composite types are assigned **type codes**, which are represented by **signed LEB128** during encoding. The hexadecimal values above are the byte values that appear when that type code is signed LEB128 encoded. For example, type code -3 corresponds to `nat`, and its LEB128 encoded result is a single byte `0x7D`.

### Composite Types

Composite types are types that contain other types internally. The following composite types are defined in Candid. In the Nim implementation, an appropriate internal representation will be used for each composite type (e.g., tuples or objects for record types, sequences for vector types).

*   **record (0x6C)** – **Record type**. A collection of named fields, each assigned a different type. It can be thought of as a tuple, but fields are assigned **hashed identifiers** (described below). It is similar to a struct type, except that **all fields are mandatory**.
*   **variant (0x6B)** – **Variant type**. This is a Tagged Union. Multiple alternative fields are defined, but **only one** of them is selected as a value, and the value is encoded along with a tag indicating which alternative is chosen. Each alternative field also has a name (hashed identifier) and a type. A variant value is represented by a tag indicating "which alternative is active" and the corresponding value (unselected alternative fields are considered non-existent).
*   **opt T (0x6E)** – **Option type**. A variable-length type that can take zero or one value of type `T`. This is essentially equivalent to a 2-case variant `variant { none; some: T }`, and holds a `null` value (no value) or a value of `T`. When encoding a value of type `opt T` in Candid, the case is indicated by an index, similar to a variant, where `0` corresponds to "no value" (`null`) and `1` to "has value", followed by the value of `T`.
*   **vec T (0x6D)** – **Vector type**. A variable-length array (sequence) of elements of type `T`. As a value, it is serialized by encoding the number of elements (non-negative integer) followed by each element in order. `vec` is used for various purposes, such as `text` being represented as `vec nat8`.
*   **func (0x6A)** – **Function reference type**. A higher-order type representing a reference to a function (canister method). The function's signature (a tuple of argument types and a tuple of return types, with optional annotations like `query` or `oneway`) is defined as a type. The value is represented by a **pair (Principal ID, function name)** indicating "a specific function of a certain canister." For example, a value of type `func (int) -> (int)` means "a pointer to a specific function of a certain service," and in practice, a principal and a function name string are sent.
*   **service (0x69)** – **Service (object) reference type**. A type representing a reference to a canister itself (or a service interface). Internally, it defines a list of methods (method names and their signatures = func types). As a value, only the **principal (canister ID)** is sent, and the receiver treats it as a service reference (Proxy). A service type is similar to a record type, but all its fields (methods) are functions.

**Field Name Hashing:** For record types, variant types, and service types, each field name (or tag name, method name) is converted to a 32-bit integer **hash value**, and identified by **that hash ID** in the binary. This is not for omitting or obfuscating field names, but for detecting changes in field names and for ordering. Candid's hash function H is defined as follows:

> H(s) = sum_{i=0 to n-1} ( s\[n-1-i] \* 223^i ) mod 2^32

That is, the field name (UTF-8 byte sequence) is treated as an integer for each byte, and multiplied by powers of 223 from the last byte, summed, and then modulo 2^32. This value is used as the ID for each field, and in the type table, this number (LEB128 encoded) is recorded instead of the field name. **Note:** Collisions (different names yielding the same hash value) are theoretically possible, but due to the 2^32 space, they are considered **easily avoidable in practice**. The Nim implementation must either implement this hash function directly or accurately reproduce it by referencing existing Candid implementations (e.g., Rust or Python versions).

### Data Structures for Composite Types in Nim

An example of internal representations for handling each composite type in Nim (adjust as needed):

*   **record**: While field names are hashed in binary, we want to handle them in the program using the names specified by the developer. Therefore, Nim will use an object type with field name and type definitions for record types. Alternatively, there's a strategy of dynamically holding a map of field name to value (e.g., a `Table[string, Value]` structure) and calculating the hash during serialization. Here, `Value` will be a union-like type (or type class) that can hold any Candid value.
*   **variant**: This also has field (tag) names and types, but as a value, it holds **only the value for one tag**. In Nim, this can be a struct that holds the tag name as a key and the corresponding value (e.g., `variantValue: (tagName: string, value: Value)`), or pre-define each possibility as an object variant. For design flexibility, a dynamic pair (current tag name and value) is preferable.
*   **opt**: Implemented using Nim's `options` module's `Option[T]` type. `opt T` is represented as `Option[T]`, where `none(T)` corresponds to a `null` value (no value) and `some(x)` represents having a value (content is of type T). For example, a value of type `opt nat` is treated as `Option[int]`, `none(int)` if null, and `some(42)` if the value is 42. In the implementation, mutual conversion with the `Option` type is performed during Candid `opt` type encoding/decoding.
*   **vec**: Held in Nim's `seq[T]` (sequence type) or an array. Since it has a length and elements of type Value, simply making it a Nim sequence enables obtaining the length during encoding and sequentially encoding each element.
*   **func**: Function references are stored as a pair `(principal: Principal, methodName: string)`. Type information (signature) needs to be stored separately, but typically `func` as a Candid value is **untyped** (the function type is meta-information, but the value itself is not type-checked at runtime). However, for safe handling, we want to retain type signatures on the Nim side as well, so a `FuncReference` struct could hold the principal, method name, and argument type list, return type list, and annotation information. During decoding, extract the principal and method name from the func value in the message and check if they match the expected type (based on the signature).
*   **service**: Service references are represented by a single `Principal` (canister ID). Additionally, the service's interface (method list and and signatures) is described in the type table. On the Nim side, a `ServiceReference` struct could hold the principal and (if possible) an interface description (e.g., a map of method names to function signatures). During decoding, obtain the service type details from the type table and save them as interface information. During encoding, only the Principal ID is sent.

## Candid Binary Format Encoding Specification

A Candid message's binary format consists of a **magic number + type table + type sequence + value sequence**, as described above. Here, we detail the encoding procedure for each part. When implementing in Nim, byte sequences are generated in this order.

### Magic Number

The first 4 bytes of the message are always the ASCII string `"DIDL"`. This corresponds to `44 49 44 4C` in hexadecimal. In the decoder implementation, the first 4 bytes are read and checked against this magic number. If they don't match, the process is aborted as a **message format error**. The encoder always outputs this constant byte sequence at the beginning of the output.

### Type Table

The **type table** is the section that enumerates the **definitions of composite types** such as records, variants, options, vectors, functions, and services. It does not include definitions for **primitive types**. The type table is encoded as follows:

1.  **Number of Entries**: First, the number of type definition entries to include in the type table is encoded using **Unsigned LEB128** (ULEB128). For example, if there are 0 type table entries, it will be `00`. If the number of entries is `n`, each type within the type table is assigned an **index** from 0 to `n-1`.
2.  **Definition of Each Entry**: Next, type definitions are outputted for each composite type in the following format. Entries are ordered sequentially from index 0. Each entry consists of a type code expressed in **signed LEB128** (e.g., 0x6C as mentioned before) followed by additional information specific to that type.

    *   **record type entry**: `0x6C` followed by the number of fields (ULEB128), and then for each field: **field ID (32-bit hash as ULEB128)** and **field type description (signed LEB128)**. If the field type description is a primitive type, use its type code; if it's a composite type, specify its **non-negative integer index** within the type table. Fields are sorted in **ascending order of hash ID**. For example, a record with 3 fields would be a byte sequence like `6C 03 <hash1> <type1> <hash2> <type2> <hash3> <type3>`.
    *   **variant type entry**: `0x6B` followed by the number of alternatives (tags) (ULEB128), then for each alternative: **tag ID hash (ULEB128)** and **value type (signed LEB128)**. The ordering and type specification are similar to records, but for variants, special care is needed for unused alternatives, anticipating future extensions (details mentioned in schema compatibility below).
    *   **opt type entry**: `0x6E` followed by **one encapsulated type** as signed LEB128. For example, for an `opt nat` type, it would be `6E 7D` (0x7D is the type code for nat). `opt` is a simple structure containing one type internally.
    *   **vec type entry**: `0x6D` followed by **one element type** (signed LEB128). For example, for a `vec text` type, it would be `6D 71` (0x71 is the type code for text).
    *   **func type entry**: `0x6A` followed by: **number of argument types (ULEB128)**, **type of each argument (signed LEB128)**..., **number of return types (ULEB128)**, **type of each return value**..., **length of annotation byte sequence (ULEB128)**, **each annotation byte**.... Annotations indicate `query` or `oneway`, using character codes `'q'` (0x71) or `'o'` (0x6F) (e.g., only `query` annotation would be length 1, byte `0x71`). If multiple annotations are present, their order is arbitrary, but current specification only has `query` and `oneway`, which are mutually exclusive, so it's 0 or 1.
    *   **service type entry**: `0x69` followed by **number of methods (ULEB128)**, then for each method: **method name hash (ULEB128)** and **method type (signed LEB128)**. The method type is a `func` type, usually represented as an index to another entry (func entry) in the type table. Method name hashing is done using power coefficients of 223, similar to fields (same method as field names). Methods are also sorted in ascending order of hash value. The service type entry itself only describes the **service interface**; the actual value (service reference value) is a principal.
3.  **Cross-Entry References**: When one type table entry references another type, **primitive types** and **compound type codes are negative**, while **in-table references are non-negative indices**. The decoder reads this value, decodes it as SLEB128, and if negative, maps it to a built-in type; if non-negative, interprets it as pointing to the corresponding index in the type table array. For example, if there's `6C 03 ... 01 ... 7A` in the above example, `01` is +1 in SLEB128, pointing to **type table entry 1**, and `0x7A` is a negative number in SLEB128 (actually the LEB representation of type code -6), so it refers to **nat16 type**.

> **Example:** If there was a service type `service Example : { foo: func (nat64) -> (opt text) query; }`, the type table would need two entries. First, the `func` signature entry (let's say #0) starts with `0x6A`, followed by 1 argument (ULEB128 `01`), type nat64 (signed LEB128 `0x78`), 1 return value (`01`), type `opt text` (opt is a composite type code, so it refers to a new entry #1, say index `01`), 1 annotation (`01`), and annotation byte `0x71` ('q'). Then, the service entry (#1) starts with `0x69`, followed by 1 method (`01`), the hash of method name "foo" (e.g., `<hashFoo>`), and type entry #0 (index `00`). Thus, the func entry and service entry would cross-reference each other (in practice, the service entry would reference the func entry).

In the Nim implementation, the following logic is used for type table construction:

*   **Type Entry Generation**: For the sequence of values to be encoded, the type of each value is inspected. If a value is a **composite type** (or contains a composite type), the corresponding type definition is added to the type table.
*   **Duplicate Removal**: Identical type structures are defined only once in the type table. For example, if multiple values use the same record type, only one entry is placed in the type table, and all refer to that index. This requires comparing types by their components (including recursive types) and hashing them, or determining equality with already existing types.
*   **Order**: The order of entries in the type table is arbitrary for implementation purposes, but generally, adding required types from values in order, e.g., via **depth-first search**, works fine. According to the Candid specification, subsequent type entries can reference preceding entries (forward references are allowed). For recursive types, a **placeholder entry** can be registered and an index allocated, allowing the type's child elements to refer back to itself. Therefore, the implementation needs to register placeholder entries and allocate indices when detecting types, to handle recursive references.
*   **Field ID Calculation and Sorting**: For records/variants/services, the IDs of fields, alternatives, and methods are calculated and **sorted in ascending order** before being stored in the type table. In Nim, after obtaining the field name to type map, hashes are calculated for each key (name), sorted numerically, and then output. Hashing is performed by the function H mentioned above.
*   **Outputting the Completed Type Table**: The constructed list of entries is individually encoded and concatenated into a byte sequence. First, the number of entries `n` is written as ULEB128, then each entry definition is written.

### Type Sequence (Types Vector)

After the type table, the **number of values** and the **type of each value** being sent in the message follow. The format is as follows:

1.  **Number of Values**: If `m` values are being sent, first encode and output `m` using **ULEB128**. This `m` would be 2 if there are two arguments in a single function call, or 0 if the return value is an empty tuple.
2.  **Type Description of Each Value**: Next, `m` **type descriptions** are output in order. Each type description is expressed as a type table index (non-negative integer) or a primitive/composite type code (negative integer), using **signed LEB128**. During encoding, determine the Candid type of each value and process as follows:

    *   If the value's type is a primitive type, output the byte of its type code (negative number) encoded as SLEB128 (e.g., 0x75 for `int32`).
    *   If the value's type is a composite type, first check its index in the type table. Since the index is determined during type table construction, output that **index value (non-negative)** encoded as ULEB128. For example, if a value corresponds to type table entry #0 (a composite type), output `00`. **Note:** Here, it's output as unsigned, but by Candid's convention, "non-negative integers are type table references." Therefore, no matter how large the index (e.g., 2^31 or more), even if the MSB is set during LEB128 encoding, if interpreted as signed and non-negative, it's treated as a type table reference. For implementation, it's simpler to encode values >= 0 directly with ULEB128, and the decoder then SLEB128 decodes it, checks if the number is non-negative, and treats it as a type table reference.
3.  The type sequence indicates what type each subsequent value is encoded as. The **decoder** first reads this part and uses it to correctly interpret the value sequence.

### Value Sequence (Values)

Finally, the serialization of each value itself follows. The binary representation of a value is determined by its type as follows:

*   **Boolean Value**: `false` is encoded as 1 byte `0x00`, `true` as `0x01`.
*   **Integer Values (arbitrary-length nat/int)**: Encoded using LEB128 unsigned/signed (see LEB128 section below). For example, `nat 300` becomes `AC 02`, `int -42` becomes `D6 7F`. Note that the length is variable depending on the value's magnitude.
*   **Fixed-Width Integer Values (nat8~nat64, int8~int64)**: Output as fixed-length byte sequences in little-endian. For example, `int32 1000` becomes 0xE8 0x03 0x00 0x00 (1000 in little-endian). Negative values are stored in two's complement.
*   **Floating-Point Numbers**: Output as IEEE 754 bit sequences in little-endian. For example, `float32 1.5` becomes 0x00 0x00 0xC0 0x3F (32-bit representation of 1.5 in IEEE754).
*   **Strings (text)**: Represented as **UTF-8 byte sequences**. First, the string length (in bytes) is output as ULEB128, followed by the UTF-8 encoded byte sequence itself. Example: `"Hi"` outputs length 2 (`0x02`), followed by `0x48 0x69`.
*   **Principal**: A principal identifier is represented by its internal byte sequence length (around 0-29 bytes) at the beginning, followed by the byte sequence body. For example, a Principal `aaaaa-aa` (around 8 bytes) would output an 8 at the beginning, then 8 bytes of data. Details adhere to ICP's Principal specification, but in Nim, during decoding, the principal byte sequence is extracted and held as is, and during encoding, the specified length and content are output.
*   **Record Value**: A record consists of multiple field values. **However, the value part does not include field names or IDs**. Instead, only the values of each field are output continuously, corresponding to the **field order in the type table (ascending hash order)**. The decoder refers to the corresponding type table entry and understands the field order and types, so it applies the read values in that order. A record value must contain all field values (in order). For example, if `record {a: int; b: bool}` was type table entry #0, the value sequence would first output `a`'s int value (LEB128 signed), followed by `b`'s bool value (1 byte).
*   **Variant Value**: A variant has only one active alternative. In the value sequence, first the **index of the selected alternative** (where index means the 0-based position in the sorted order of alternatives defined in the variant entry of the type table) is output as ULEB128, followed by the actual value of that alternative. For example, if a value of type `variant { ok:int; err:text }` is `err: "Bad"`, then alternative `err` is the second (index 1), so `01` is output, followed by the length and byte sequence of text `"Bad"`. Variant values do not contain information about unselected alternatives.
*   **Opt Value**: `opt` is essentially equivalent to the `none`/`some` dichotomy of a variant, so encoding is similar. First, output a tag of 0 or 1 (0=no value, 1=has value), and if 1, continue by encoding the internal value. For example, `opt nat` value that is `null` becomes `00`, and value `42` becomes `01 2A` (01 is the some tag, 2A is 42 in LEB128).
*   **Vec Value**: A vector is a variable-length array, so its **number of elements** is output as ULEB128, followed by each element encoded in order. For example, if `vec nat8` is the byte sequence `\[0x48,0x69\]` (characters "Hi"), first its length 2 (`0x02`), followed by `0x48 0x69`.
*   **Func Value**: A function reference is a **principal + function name** pair. First, output the principal's byte sequence length and data, followed by the function name's length (in UTF-8 bytes) and the function name's byte sequence. For example, for a reference to a method `m` on a canister `p`, it would be `<len(p)> <p_bytes> <len("m")> "m"`. Annotations (query/oneway) are not included in the value sequence; they are meta-information existing only within the func type definition in the type table.
*   **Service Value**: A service reference outputs only the **principal**. The format is the same as a principal value: byte sequence length at the beginning, then the ID body. Since the list of methods included in the service type is communicated to the recipient via the type table, only the ID is needed as a value. The recipient will use the principal to construct a proxy for that service (canister).

Thus, the value sequence is serialized according to the **type information declared in the type sequence**. The decoder, based on the type of each value obtained beforehand, performs appropriate byte reading and LEB128 parsing to convert it to the corresponding Nim internal representation.

**Example of Value Sequence:**
Let's encode a concrete value of the HTTP response record type (fields: body: `vec nat8`, headers: `vec empty`, status_code: `nat16`) from the type table example, specifically "body=\"Hi, all!\"", headers=\[], status_code=200". Assuming the type table and type sequence are already prepared, the value sequence part would be as follows:

*   `0x01` – Argument tuple length (here, 1 because only one record is sent).
*   `0x00` – Type specification in the type sequence (assuming this record was type table entry #0, so it points to 0). *This part is actually included in the type sequence but reiterated for value understanding.*
*   **body field value**: `"Hi, all!"` has 8 bytes, so first output length 8 (`0x08`), then `48 69 2C 20 61 6C 6C 21` (UTF-8 code for "Hi, all!").
*   **headers field value**: An empty vector, so length 0 is outputted as ULEB128 `0x00`. There are no subsequent elements (its type is `empty`, so it cannot contain elements by definition).
*   **status_code field value**: 200 is `nat16`, so 16-bit little-endian `0xC8 0x00` is output (0x00C8 is decimal 200).

This completes the value sequence. The full message byte sequence for this example is as follows (including DIDL and type table parts):

```
44 49 44 4C    ; "DIDL"
03            ; Type table entry count = 3
6C 03         ; Type entry 0: record, field count = 3
  A2 F5 ED 88 04 01   ; Field ID 1 (e.g., hash of "body") and Type = entry 1 (vec nat8)
  C6 A4 A1 98 06 02   ; Field ID 2 ("headers" hash) and Type = entry 2 (vec empty)
  9A A1 B2 F9 0C 7A   ; Field ID 3 ("status_code" hash) and Type = 0x7A (nat16)
6D 7B         ; Type entry 1: vec, element type = 0x7B (nat8)
6D 6F         ; Type entry 2: vec, element type = 0x6F (empty)
01            ; Value sequence value count = 1 (1 argument)
00            ; Type of that value = type table entry 0 (record)
08 48 69 2C 20 61 6C 6C 21   ; body field: vec nat8 length 8 and 8 bytes ("Hi, all!")
00            ; headers field: vec empty length 0
C8 00         ; status_code field: nat16 = 200
```

(The values in the byte sequence above are based on Monic tool output)

## LEB128 Encoding Method and Implementation

In Candid encoding, **LEB128 (Little-Endian Base 128)** is frequently used as a variable-length integer representation. It is used in various places, such as type codes and type table indices (signed LEB128), arbitrary-length `nat` and `int` values (unsigned/signed LEB128 respectively), and size information (unsigned LEB128). When implementing this in Nim, it's necessary to understand the principles of LEB128 and encode/decode efficiently.

### Unsigned LEB128 (ULEB128)

**Unsigned LEB128** is an encoding method that represents non-negative integers as variable-length byte sequences. It segments values into 7-bit groups from least significant to most significant and forms bytes, using the most significant bit (MSB) of each byte as a "more bytes follow" flag. The specific procedure is as follows:

1.  Prepare the binary representation of the number to be encoded (zero-extend to make its length a multiple of 7 bits if necessary).
2.  Divide into 7-bit groups from the least significant end. Each group will go into the lower 7 bits of a byte.
3.  For each 7-bit group, create a byte: place the **group's value in the lower 7 bits**. Additionally, set the **upper 1 bit** (8th bit) to 1 "if subsequent bytes exist," and to 0 for the last group.
4.  The least significant (first extracted) 7-bit group is output as the **first byte**, and subsequent bytes for higher groups are output in order. The result will be in little-endian order, where **lower groups appear first**.

For small values, it fits into 1 byte (MSB is 0, indicating termination). For example, 0 is `00`, 127 is `7F` (0111_1111). For values 128 (0x80) or greater, like 128, it outputs `80` with MSB 1 for the lower 7 bits (0), and then the next byte `01`, resulting in `80 01`.

**Example:** ULEB128 encoding of the non-negative integer 624485:

*   The binary of 624485 is `10011000011101100101` (20 bits).
*   Zero-pad to 7-bit boundaries: `010011000011101100101` (21 bits).
*   Dividing into 7-bit segments: `[0100110] [0001110] [1100101]`.
*   Arranging each group in reverse order, and adding MSB=1 to the first two groups and MSB=0 to the last group, the byte sequence becomes `0x26 0x8E 0xE5`.
*   To arrange in little-endian order (outputting from the least significant group), the encoded result is `E5 8E 26`.

Thus, **smaller values result in shorter byte sequences**, and larger values add bytes in 7-bit increments. In Nim, unsigned LEB128 can be implemented with steps like these:

```nim
proc uleb128Encode(x: uint64): seq[byte] =
  ## Encodes a 64-bit integer to unsigned LEB128 and returns a byte sequence
  result = @[]
  var value = x
  while true:
    var byteVal = value and 0x7Fu64            # Get lower 7 bits
    value = value shr 7                       # Right shift 7 bits (logical, not arithmetic)
    if value == 0:
      result.add(byte(byteVal))               # Add with no-follow flag (MSB=0)
      break
    else:
      result.add(byte(byteVal or 0x80u64))    # Add with follow flag (MSB=1)
    # Loop continues
```

For arbitrary-length integers (BigInt), it can be implemented similarly by processing 7 bits at a time.

### Signed LEB128 (SLEB128)

**Signed LEB128** is a variable-length encoding method for integers, including negative numbers. The basic concept is similar to unsigned, but it uses **two's complement** and has different termination conditions for the last byte. The procedure is:

1.  Convert the integer to be encoded to its binary two's complement representation (sign-extend to make its length a multiple of 7 bits).
2.  Divide the bit sequence into 7-bit segments from the least significant end and form bytes sequentially. The lower 7 bits of each byte are the group's value, and the MSB is generally a "more bytes follow" flag, but the termination condition differs from unsigned.
3.  **Determination**: After outputting each byte, right-shift the original value, including the sign bit (fill with 1s for negative numbers, 0s for positive). If **the remaining value is all 0s or all 1s (corresponding to the sign bit), AND the sign bit of the current byte (7th bit) matches the sign of the original value**, then that byte is output with MSB=0 as the last byte, and the loop terminates. Otherwise, output with MSB=1 and continue.
4.  For negative numbers, since they are infinitely filled with 1s, the termination condition is met when at some point "the rest are all 1s" and the top bit of the current group is also 1. For positive numbers, it terminates when the rest are all 0s and the top bit of the current group is 0.

**Example:** SLEB128 encoding of -123456:

*   Prepare the binary of 123456 (17 bits) and sign-extend to 21 bits (7 bits x 3).
*   Calculate the 21-bit two's complement of 123456 (representing -123456), which gives `1111000 0111011 1000000` (each 7 bits).
*   When converting each 7-bit group to a byte, it would be `[01111000] [10111011] [11000000]`, but for signed numbers, since it's negative, the MSB of the last byte (here 11000000) becomes 0 (terminates when remaining bits are all 1s and sign is 1).
*   Since the output order is little-endian (reversed), the encoded result is `C0 BB 78`.

In SLEB128 implementation, handling the sign bit and termination condition are key. Nim pseudo-code might look like this:

```nim
proc sleb128Encode(x: int64): seq[byte] =
  ## Encodes a 64-bit integer to signed LEB128
  result = @[]
  var value = x
  let negative = (x < 0)
  while true:
    var byteVal = value and 0x7Fi64         # Lower 7 bits
    value = value shr 7                    # Arithmetic shift (propagates sign bit)
    # Check if sign bit differs from value to be output, or if value remains
    if (value == 0 and (byteVal and 0x40) == 0) or (value == -1 and (byteVal and 0x40) != 0):
      result.add(byte(byteVal))            # Termination condition: output with MSB=0 and loop ends
      break
    else:
      result.add(byte(byteVal or 0x80i64)) # Continue: output with MSB=1
```

Here, `0x40` refers to the 7th bit (6th with 0-index), and if `byteVal and 0x40` is non-zero, the current value's sign bit is 1 (meaning negative).

### Decoding in Nim

Decoding reverses the encoding procedure. **ULEB128 decoding** reads byte by byte: if MSB is 1, it accumulates the lower 7 bits and reads the next byte; it terminates on a byte with MSB 0. **SLEB128 decoding** similarly accumulates 7 bits at a time, and if the MSB (sign) of the last byte is 1, it sign-extends the received value. That is, if the 7th bit of the last byte is 1, all subsequent higher bits are set to 1 to reconstruct the negative number.

In Nim, for small integers, these fit into 64 bits. However, Candid allows arbitrary-length `nat`/`int`, so if necessary, conversion to `BigInt` (arbitrary-precision integer) is required. Fortunately, LEB128 itself can be processed byte by byte regardless of length, so for cases exceeding 64 bits, an approach of shifting and adding to a `BigInt` within a loop is feasible.

## Type and Value Correspondence, Order, and Schema Consistency

To correctly interpret an encoded Candid message, the **correspondence between types and values** must be maintained. The value sequence output by the sender corresponds **in order** to the types declared in the preceding type sequence. When implementing a decoder in Nim, the following points should be noted:

*   **Value Order**: In Candid, the entire message is treated as a tuple (a group of multiple values). For example, if a function has multiple arguments, they are ordered sequentially. During decoding, first the tuple length is obtained, then types are read that many times, followed by reading values, to reproduce the value list in the same order. It is crucial to always extract values in **the same order as they were encoded**.
*   **Type Interpretation**: Each value is interpreted based on its corresponding type information. For example, if the first type in the type sequence is `int`, the first byte sequence in the value sequence is read as LEB128 signed and stored in Nim's `int` type. If the second is `vec nat8`, the second value sequence first obtains the length using ULEB128, then reads that many bytes to construct the array. The implementation requires a mechanism to **dispatch the appropriate reading function based on the type code or index**.
*   **Field Order**: For fields within records and variants, as mentioned, the **order sorted in the type table** is also reflected in the values. Records have positional correspondence, and variants have the chosen alternative index appearing first, preserving the structure. Therefore, the decoder remembers the definition order in the type table and, for example, understands "record type #i has 3 fields (in ID order), so this value consists of 3 parts in that order" and reads them accordingly. Conversely, when reproducing decoded values (e.g., for text display), this order and ID must be used for mapping to original field names. 