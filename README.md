# NYCU DCLab Final - Tetris 俄羅斯方塊

## Score Checkpoint

- 基本功能 60% 16pts
    - [ ] 畫出俄羅斯方塊的背景。 10 x 20
    - [ ] 畫出至少7種不同方塊。  
      1.I 2.J 3.L 4.O 5.S 6.T 7.Z  
      ![](https://learnopencv.com/wp-content/uploads/2020/11/tetris-pieces.png)
    - [ ] 會越疊愈高，並且可消除，往下掉。
    - [ ] 方塊可旋轉。
    - [ ] 遊戲畫面有邊界。
    - [ ] 使用button或是switch進行控制遊戲與互動。
- 進階功能 40% 12pts
    - [ ] 設計計分系統。
    - [ ] T轉。
    - [ ] 有Buffer功能可以換方塊。
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
wire [2:0] kind, hold, next [0:3];
```

### Control

```mermaid
graph TD;
```

### Tetris

```mermaid
stateDiagram-v2
direction LR
[*] --> INIT
INIT --> GEN
GEN --> NEXT
NEXT --> END     :overlap
END --> [*]
NEXT --> WAIT
WAIT --> ROTATE : ctrl-rot
WAIT --> LEFT   : ctrl-left
WAIT --> DOWN   : ctrl-down
WAIT --> RIGHT  : ctrl-right
WAIT --> BAR    : ctrl-bar
WAIT --> HOLD   : ctrl-hold
state WAIT_IF <<choice>>
ROTATE --> WAIT_IF
LEFT   --> WAIT_IF
DOWN   --> WAIT_IF
RIGHT  --> WAIT_IF
HOLD   --> NEXT
BAR    --> WAIT_IF
WAIT_IF --> WAIT
WAIT_IF --> END    :overlap
WAIT_IF --> CLEAR  :stop
CLEAR --> GEN
```

### Display

```mermaid
graph TD;
```
