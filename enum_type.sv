package enum_type;
  localparam QSIZE = 16;
  localparam SEC_TICK  = 50_000_000;
  localparam COUNT_SEC = 60;
  localparam DOWN_TICK = SEC_TICK;
  localparam BAR_TICK  = SEC_TICK * 5 * 4;
  localparam OVER_TICK = SEC_TICK * 1;

  typedef enum bit [7:0] {
    NONE = 0,
    INIT, GEN, WAIT,
    LEFT, RIGHT, DOWN, DROP,
    HOLD, ROTATE, ROTATE_REV, BAR,
    PCHECK, DCHECK, MCHECK, HCHECK,
    CPREP, CLEAR, BPLACE, END
  } state_type;
endpackage
