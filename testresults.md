```text
Sudoku benchmark
Puzzle: easy
Repeat count: 1000000

impl   status                               avg ms/run  puzzles/sec     wall sec
----------------------------------------------------------------------------------
c      ok                                     0.004304    232342.01        4.304
zig    ok                                     0.004626    216169.48        4.627
odin   ok                                     0.004776    209380.23        4.777
go     ok                                     0.005186    192826.84        5.187
rust   ok                                     0.006161    162311.31        6.162
```

```text
Sudoku benchmark
Puzzle: hard
Repeat count: 1000000

impl   status                               avg ms/run  puzzles/sec     wall sec
----------------------------------------------------------------------------------
c      ok                                     0.036103     27698.53       36.104
zig    ok                                     0.042886     23317.63       42.886
odin   ok                                     0.043144     23178.19       43.146
go     ok                                     0.043328     23079.76       43.330
rust   ok                                     0.055663     17965.26       55.664
```