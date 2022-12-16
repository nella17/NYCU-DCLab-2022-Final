package enum_type;
  typedef enum {
    NOEVENT = 0,
    LEFT, RIGHT, DOWN, DROP,
    HOLD, ROTATE, ROTATE_REV, BAR
  } control_type;

  typedef enum {
    INIT, GEN, WAIT,
    LEFT, RIGHT, DOWN, DROP,
    HOLD, ROTATE, ROTATE_REV, BAR,
    PCHECK, DCHECK, MCHECK, HCHECK, BCHECK,
    CLEAR, END
  } state_type;
endpackage
