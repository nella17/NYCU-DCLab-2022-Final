package enum_type;
  typedef enum bit [7:0] {
    NONE = 0,
    INIT, GEN, WAIT,
    LEFT, RIGHT, DOWN, DROP,
    HOLD, ROTATE, ROTATE_REV, BAR,
    PCHECK, DCHECK, MCHECK, HCHECK, BCHECK,
    CPREP, CLEAR, END
  } state_type;
endpackage
