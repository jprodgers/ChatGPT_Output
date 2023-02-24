/*
  This is a basic minesweep clone, written mostly by ChatGPT.
*/

int cols = 20;
int rows = 20;
int w = 20;
int totalMines = 40;
Cell[][] grid = new Cell[cols][rows];
boolean gameOver = false;

void settings() {
  size(cols * w, rows * w);
}

void setup() {
  initGrid();
  placeMines();
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      grid[i][j].countMines();
    }
  }
}

void initGrid() {
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      grid[i][j] = new Cell(i, j, w);
    }
  }
}

void placeMines() {
  int count = 0;
  while (count < totalMines) {
    int i = floor(random(cols));
    int j = floor(random(rows));
    if (!grid[i][j].mine) {
      grid[i][j].mine = true;
      count++;
    }
  }
}

void draw() {
  background(255);
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      grid[i][j].show();
    }
  }
}

void mousePressed() {
  if (!gameOver) {
    int i = floor(mouseX / w);
    int j = floor(mouseY / w);
    if (mouseButton == LEFT) {
      if (grid[i][j].mine) {
        revealMines();
        gameOver = true;
      } else {
        grid[i][j].reveal();
      }
    } else if (mouseButton == RIGHT) {
      grid[i][j].toggleFlag();
    }
    checkWin();
  }
}

void revealMines() {
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (grid[i][j].mine) {
        grid[i][j].revealed = true;
      }
    }
  }
}

void checkWin() {
  boolean win = true;
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (!grid[i][j].mine && !grid[i][j].revealed) {
        win = false;
        break;
      }
    }
  }
  if (win) {
    gameOver = true;
    revealMines();
  }
}

class Cell {
  int i, j;
  int w;
  boolean mine;
  boolean revealed;
  boolean flag;
  int neighborCount;

  Cell(int i, int j, int w) {
    this.i = i;
    this.j = j;
    this.w = w;
    this.mine = false;
    this.revealed = false;
    this.flag = false;
    this.neighborCount = 0;
  }

  void show() {
    stroke(0);
    noFill();
    rect(i * w, j * w, w, w);
    if (revealed) {
      if (mine) {
        fill(127);
        ellipse(i * w + w/2, j * w + w/2, w/2, w/2);
      } else {
        fill(200);
        rect(i * w, j * w, w, w);
        if (neighborCount > 0) {
          textAlign(CENTER);
          textSize(w);
          if(neighborCount == 1) fill(0,0,255);
          else if(neighborCount == 2) fill(0,255,0);
          else if(neighborCount == 3) fill(255,255,0);
          else if(neighborCount >= 4) fill(255,0,0);
          text(neighborCount, i * w + w/2, j * w + (w-2));
        }
      }
    } else if (flag) {
      fill(0);
      textAlign(CENTER);
      textSize(w);
      fill(255,0,0);
      text("F", i * w + w/2, j * w + (w-2));
    }
  }

  void countMines() {
    if (mine) {
      neighborCount = -1;
      return;
    }
    int total = 0;
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        int i = this.i + x;
        int j = this.j + y;
        if (i >= 0 && j >= 0 && i < cols && j < rows) {
          if (grid[i][j].mine) {
            total++;
          }
        }
      }
    }
    neighborCount = total;
  }

  void reveal() {
    revealed = true;
    if (neighborCount == 0) {
      floodFill();
    }
  }

  void toggleFlag() {
    if (!revealed) {
      flag = !flag;
    }
  }

  void floodFill() {
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        int i = this.i + x;
        int j = this.j + y;
        if (i >= 0 && j >= 0 && i < cols && j < rows) {
          Cell neighbor = grid[i][j];
          if (!neighbor.mine && !neighbor.revealed) {
            neighbor.reveal();
          }
        }
      }
    }
  }
}
