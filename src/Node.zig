tag: Tag,
data: Data,

pub const Tag = enum(u8) {
    Add,
    Sub,
    Mul,
    Div,

    Integer,
    Double,

    UnaryNegation,
};

pub const Data = union {
    /// left + right point to indexes in the node list
    Binary: struct {
        left: u64,
        right: u64,
    },

    /// contains a nodeidx or a tokidx
    Unary: u64,
};
