tag: Tag,
data: Data,

const Tag = enum(u8) {
    Add,
    Sub,
    Mul,
    Div,
};

const Data = union {
    /// left + right point to indexes in the node list
    Binary: struct {
        .left = u64,
        .right = u64,
    },

    Identifier: u64,

    Integer: i64,
    Double: f64,
};
