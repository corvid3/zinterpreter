tag: Tag,
slice: []const u8,

pub const Tag = enum(u8) {
    // special tag used to make parsing easier
    EOF,

    Identifier,

    // all integers will be signed 64-bit vals,
    //     TODO: eventually implement bignum
    Integer,

    // all floating point values will be double-precision
    Double,

    Plus,
    Minus,
    Asterisk,
    Solidus,

    LeftParanthesis,
    RightParanthesis,
};
