# Option Types {#sec-option-types}

Overall the basic option types are the same in Project Manager as NixOS. A
few Project Manager options, however, make use of custom types that are
worth describing in more detail. These are the option types `dagOf` and
`gvariant` that are used, for example, by
[project.activation](#opt-project.activation).

[]{#sec-option-types-dag}`hm.types.dagOf`

: Options of this type have attribute sets as values where each member
is a node in a [directed acyclic
graph](https://en.wikipedia.org/w/index.php?title=Directed_acyclic_graph&oldid=939656095)
(DAG). This allows the attribute set entries to express dependency
relations among themselves. This can, for example, be used to
control the order of match blocks in a OpenSSH client configuration
or the order of activation script blocks in
[project.activation](#opt-project.activation).

    A number of functions are provided to create DAG nodes. The
    functions are shown below with examples using an option `foo.bar` of
    type `hm.types.dagOf types.int`.

    []{#sec-option-types-dag-entryAnywhere}`hm.dag.entryAnywhere (value: T) : DagEntry<T>`

    :   Indicates that `value` can be placed anywhere within the DAG.
        This is also the default for plain attribute set entries, that
        is

        ``` nix
        foo.bar = {
          a = hm.dag.entryAnywhere 0;
        }
        ```

        and

        ``` nix
        foo.bar = {
          a = 0;
        }
        ```

        are equivalent.

    []{#sec-option-types-dag-entryAfter}`hm.dag.entryAfter (afters: list string) (value: T) : DagEntry<T>`

    :   Indicates that `value` must be placed *after* each of the
        attribute names in the given list. For example

        ``` nix
        foo.bar = {
          a = 0;
          b = hm.dag.entryAfter [ "a" ] 1;
        }
        ```

        would place `b` after `a` in the graph.

    []{#sec-option-types-dag-entryBefore}`hm.dag.entryBefore (befores: list string) (value: T) : DagEntry<T>`

    :   Indicates that `value` must be placed *before* each of the
        attribute names in the given list. For example

        ``` nix
        foo.bar = {
          b = hm.dag.entryBefore [ "a" ] 1;
          a = 0;
        }
        ```

        would place `b` before `a` in the graph.

    []{#sec-option-types-dag-entryBetween}`hm.dag.entryBetween (befores: list string) (afters: list string) (value: T) : DagEntry<T>`

    :   Indicates that `value` must be placed *before* the attribute
        names in the first list and *after* the attribute names in the
        second list. For example

        ``` nix
        foo.bar = {
          a = 0;
          c = hm.dag.entryBetween [ "b" ] [ "a" ] 2;
          b = 1;
        }
        ```

        would place `c` before `b` and after `a` in the graph.

    There are also a set of functions that generate a DAG from a list.
    These are convenient when you just want to have a linear list of DAG
    entries, without having to manually enter the relationship between
    each entry. Each of these functions take a `tag` as argument and the
    DAG entries will be named `${tag}-${index}`.

    []{#sec-option-types-dag-entriesAnywhere}`hm.dag.entriesAnywhere (tag: string) (values: [T]) : Dag<T>`

    :   Creates a DAG with the given values with each entry labeled
        using the given tag. For example

        ``` nix
        foo.bar = hm.dag.entriesAnywhere "a" [ 0 1 ];
        ```

        is equivalent to

        ``` nix
        foo.bar = {
          a-0 = 0;
          a-1 = hm.dag.entryAfter [ "a-0" ] 1;
        }
        ```

    []{#sec-option-types-dag-entriesAfter}`hm.dag.entriesAfter (tag: string) (afters: list string) (values: [T]) : Dag<T>`

    :   Creates a DAG with the given values with each entry labeled
        using the given tag. The list of values are placed are placed
        *after* each of the attribute names in `afters`. For example

        ``` nix
        foo.bar =
          { b = 0; }
          // hm.dag.entriesAfter "a" [ "b" ] [ 1 2 ];
        ```

        is equivalent to

        ``` nix
        foo.bar = {
          b = 0;
          a-0 = hm.dag.entryAfter [ "b" ] 1;
          a-1 = hm.dag.entryAfter [ "a-0" ] 2;
        }
        ```

    []{#sec-option-types-dag-entriesBefore}`hm.dag.entriesBefore (tag: string) (befores: list string) (values: [T]) : Dag<T>`

    :   Creates a DAG with the given values with each entry labeled
        using the given tag. The list of values are placed *before* each
        of the attribute names in `befores`. For example

        ``` nix
        foo.bar =
          { b = 0; }
          // hm.dag.entriesBefore "a" [ "b" ] [ 1 2 ];
        ```

        is equivalent to

        ``` nix
        foo.bar = {
          b = 0;
          a-0 = 1;
          a-1 = hm.dag.entryBetween [ "b" ] [ "a-0" ] 2;
        }
        ```

    []{#sec-option-types-dag-entriesBetween}`hm.dag.entriesBetween (tag: string) (befores: list string) (afters: list string) (values: [T]) : Dag<T>`

    :   Creates a DAG with the given values with each entry labeled
        using the given tag. The list of values are placed *before* each
        of the attribute names in `befores` and *after* each of the
        attribute names in `afters`. For example

        ``` nix
        foo.bar =
          { b = 0; c = 3; }
          // hm.dag.entriesBetween "a" [ "b" ] [ "c" ] [ 1 2 ];
        ```

        is equivalent to

        ``` nix
        foo.bar = {
          b = 0;
          c = 3;
          a-0 = hm.dag.entryAfter [ "c" ] 1;
          a-1 = hm.dag.entryBetween [ "b" ] [ "a-0" ] 2;
        }
        ```

[]{#sec-option-types-gvariant}`hm.types.gvariant`

: This type is useful for options representing
[`GVariant`](https://docs.gtk.org/glib/struct.Variant.html#description)
values. The type accepts all primitive `GVariant` types as well as
arrays, tuples, "maybe" types, and dictionaries.

    Some Nix values are automatically coerced to matching GVariant value
    but the GVariant model is richer so you may need to use one of the
    provided constructor functions. Examples assume an option `foo.bar`
    of type `hm.types.gvariant`.

    []{#sec-option-types-gvariant-mkBoolean}`hm.gvariant.mkBoolean (v: bool)`

    :   Takes a Nix value `v` to a GVariant `boolean` value (GVariant
        format string `b`). Note, Nix booleans are automatically coerced
        using this function. That is,

        ``` nix
        foo.bar = hm.gvariant.mkBoolean true;
        ```

        is equivalent to

        ``` nix
        foo.bar = true;
        ```

    []{#sec-option-types-gvariant-mkString}`hm.gvariant.mkString (v: string)`

    :   Takes a Nix value `v` to a GVariant `string` value (GVariant
        format string `s`). Note, Nix strings are automatically coerced
        using this function. That is,

        ``` nix
        foo.bar = hm.gvariant.mkString "a string";
        ```

        is equivalent to

        ``` nix
        foo.bar = "a string";
        ```

    []{#sec-option-types-gvariant-mkObjectpath}`hm.gvariant.mkObjectpath (v: string)`

    :   Takes a Nix value `v` to a GVariant `objectpath` value (GVariant
        format string `o`).

    []{#sec-option-types-gvariant-mkUchar}`hm.gvariant.mkUchar (v: string)`

    :   Takes a Nix value `v` to a GVariant `uchar` value (GVariant
        format string `y`).

    []{#sec-option-types-gvariant-mkInt16}`hm.gvariant.mkInt16 (v: int)`

    :   Takes a Nix value `v` to a GVariant `int16` value (GVariant
        format string `n`).

    []{#sec-option-types-gvariant-mkUint16}`hm.gvariant.mkUint16 (v: int)`

    :   Takes a Nix value `v` to a GVariant `uint16` value (GVariant
        format string `q`).

    []{#sec-option-types-gvariant-mkInt32}`hm.gvariant.mkInt32 (v: int)`

    :   Takes a Nix value `v` to a GVariant `int32` value (GVariant
        format string `i`). Note, Nix integers are automatically coerced
        using this function. That is,

        ``` nix
        foo.bar = hm.gvariant.mkInt32 7;
        ```

        is equivalent to

        ``` nix
        foo.bar = 7;
        ```

    []{#sec-option-types-gvariant-mkUint32}`hm.gvariant.mkUint32 (v: int)`

    :   Takes a Nix value `v` to a GVariant `uint32` value (GVariant
        format string `u`).

    []{#sec-option-types-gvariant-mkInt64}`hm.gvariant.mkInt64 (v: int)`

    :   Takes a Nix value `v` to a GVariant `int64` value (GVariant
        format string `x`).

    []{#sec-option-types-gvariant-mkUint64}`hm.gvariant.mkUint64 (v: int)`

    :   Takes a Nix value `v` to a GVariant `uint64` value (GVariant
        format string `t`).

    []{#sec-option-types-gvariant-mkDouble}`hm.gvariant.mkDouble (v: double)`

    :   Takes a Nix value `v` to a GVariant `double` value (GVariant
        format string `d`). Note, Nix floats are automatically coerced
        using this function. That is,

        ``` nix
        foo.bar = hm.gvariant.mkDouble 3.14;
        ```

        is equivalent to

        ``` nix
        foo.bar = 3.14;
        ```

    []{#sec-option-types-gvariant-mkArray}`hm.gvariant.mkArray type elements`

    :   Builds a GVariant array containing the given list of elements,
        where each element is a GVariant value of the given type
        (GVariant format string `a${type}`). The `type` value can be
        constructed using

        -   `hm.gvariant.type.string` (GVariant format string `s`)

        -   `hm.gvariant.type.boolean` (GVariant format string `b`)

        -   `hm.gvariant.type.uchar` (GVariant format string `y`)

        -   `hm.gvariant.type.int16` (GVariant format string `n`)

        -   `hm.gvariant.type.uint16` (GVariant format string `q`)

        -   `hm.gvariant.type.int32` (GVariant format string `i`)

        -   `hm.gvariant.type.uint32` (GVariant format string `u`)

        -   `hm.gvariant.type.int64` (GVariant format string `x`)

        -   `hm.gvariant.type.uint64` (GVariant format string `t`)

        -   `hm.gvariant.type.double` (GVariant format string `d`)

        -   `hm.gvariant.type.variant` (GVariant format string `v`)

        -   `hm.gvariant.type.arrayOf type` (GVariant format string
            `a${type}`)

        -   `hm.gvariant.type.maybeOf type` (GVariant format string
            `m${type}`)

        -   `hm.gvariant.type.tupleOf types` (GVariant format string
            `(${lib.concatStrings types})`)

        -   `hm.gvariant.type.dictionaryEntryOf [keyType valueType]`
            (GVariant format string `{${keyType}${valueType}}`)

        where `type` and `types` are themselves a type and list of
        types, respectively.

    []{#sec-option-types-gvariant-mkEmptyArray}`hm.gvariant.mkEmptyArray type`

    :   An alias of
        [`hm.gvariant.mkArray type []`](#sec-option-types-gvariant-mkArray).

    []{#sec-option-types-gvariant-mkNothing}`hm.gvariant.mkNothing type`

    :   Builds a GVariant maybe value (GVariant format string
        `m${type}`) whose (non-existent) element is of the given type.
        The `type` value is constructed as described for the
        [`mkArray`](#sec-option-types-gvariant-mkArray) function above.

    []{#sec-option-types-gvariant-mkJust}`hm.gvariant.mkJust element`

    :   Builds a GVariant maybe value (GVariant format string
        `m${element.type}`) containing the given GVariant element.

    []{#sec-option-types-gvariant-mkTuple}`hm.gvariant.mkTuple elements`

    :   Builds a GVariant tuple containing the given list of elements,
        where each element is a GVariant value.

    []{#sec-option-types-gvariant-mkVariant}`hm.gvariant.mkVariant element`

    :   Builds a GVariant variant (GVariant format string `v`) which
        contains the value of a GVariant element.

    []{#sec-option-types-gvariant-mkDictionaryEntry}`hm.gvariant.mkDictionaryEntry [key value]`

    :   Builds a GVariant dictionary entry containing the given list of
        elements (GVariant format string `{${key.type}${value.type}}`),
        where each element is a GVariant value.
