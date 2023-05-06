tag: Tag,
slice: []const u8,

pub const Tag = enum(u8) {
    // special tag used to make parsing easier
    NULL,

    Identifier,
    Number, // all numbers will be parsed as double-precision floats

    Plus,
    Minus,
    Asterisk,
    Solidus,
};
