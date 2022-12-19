# NYCU DCLab Final - Tetris 俄羅斯方塊

## Score Checkpoint

- 基本功能 60% 16pts
    - [ ] 畫出俄羅斯方塊的背景。 10 x 20
    - [x] 畫出至少7種不同方塊。  
      1.I 2.J 3.L 4.O 5.S 6.T 7.Z  
      0.none 8.bar
         ![](https://learnopencv.com/wp-content/uploads/2020/11/tetris-pieces.png)
    - [x] 會越疊愈高，並且可消除，往下掉。
    - [x] 方塊可旋轉。
    - [ ] 遊戲畫面有邊界。
    - [x] 使用button或是switch進行控制遊戲與互動。
- 進階功能 40% 12pts
    - [ ] 設計計分系統。
    - [x] T轉。
    - [x] 有Buffer功能可以換方塊。
    - [ ] 隨機生成障礙。
- 額外功能 20% 6pts
    - [ ] 使用者介面 (如: 介面精緻等)
    - [ ] 使用者體驗 (如: 流暢度等)
    - [ ] 添加創新的功能


## CFG

```mermaid
%%{ init: { 'flowchart': { 'curve': 'basis' } } }%%
graph LR;
usr_btn; uart; VGA;
Control; Tetris; Display;

uart --> Control;
usr_btn --> Control;

Control --> Tetris;

Display -->|x, y| Tetris;
Tetris -->|"score, kind, hold, next[4]"| Display;

Display --> VGA;
```

```verilog
// 10 x 20
wire [4:0] x, y;
// x, y -> kind
wire [4*4-1:0] score; // 0xABCD BCD
wire [3:0] kind, hold, next [0:3];
```

### Control

- NONE
- LEFT
  - A
  - btn2
- RIGHT
  - D
  - btn0
- DOWN
  - S
  - btn1
- DROP
  - W
  - space
  - sw0
- HOLD
  - C
  - btn3
- ROTATE
  - X
  - sw1
- ROTATE_REV
  - Z
  - sw2
- BAR
  - B
  - sw3


### Tetris

```mermaid
stateDiagram-v2
direction LR
[*] --> INIT
INIT --> GEN    : ctrl
GEN --> WAIT
WAIT --> DROP   : ctrl-DROP
WAIT --> DOWN   : ctrl-DOWN
WAIT --> LEFT   : ctrl-LEFT
WAIT --> RIGHT  : ctrl-RIGHT
WAIT --> ROTATE : ctrl-ROTATE
WAIT --> ROTATE_REV : ctrl-ROTATE_REV
WAIT --> HOLD   : ctrl-HOLD
WAIT --> BAR    : ctrl-BAR
DROP --> PCHECK
DOWN --> DCHECK
LEFT --> MCHECK
RIGHT --> MCHECK
ROTATE --> MCHECK
BAR --> WAIT
ROTATE_REV --> MCHECK
HOLD --> HCHECK
PCHECK --> DROP     : valid
state CLEAR_END <<choice>>
PCHECK --> CLEAR_END : !valid
DCHECK --> CLEAR_END : !valid
state WAIT_ <<choice>>
DCHECK --> WAIT_     : valid
MCHECK --> WAIT_
HCHECK --> WAIT_     : hold != 0
HCHECK --> GEN       : hold = 0
WAIT_ --> WAIT
CLEAR_END --> CPREP  : !outside
CLEAR_END --> END    : outside
END --> INIT         : ctrl
CPREP --> CLEAR
CLEAR --> CPREP      : do_clear
CLEAR --> BPLACE     : finished
BPLACE --> END       : boutside
BPLACE --> GEN       : !boutside
```

### Display

```mermaid
graph TD;
```
