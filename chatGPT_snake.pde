/*
  A basic Snake clone, written largely by ChatGPT. Some corrections had to be
  made to compile, and a reset feature was added
*/


final int BLOCK_SIZE = 20;
final int BOARD_WIDTH = 50;
final int BOARD_HEIGHT = 50;
final int UPDIR = 0;
final int DOWNDIR = 1;
final int LEFTDIR = 2;
final int RIGHTDIR = 3;

boolean HAS_GROWN = false;

int[][] snake = new int[1][2];
int[] food = new int[2];
int score = 0;
int direction = int(random(4));

void settings(){
  size(BOARD_WIDTH * BLOCK_SIZE, BOARD_HEIGHT * BLOCK_SIZE);
}

void setup() {
  frameRate(10);
  initializeGame();
}

void draw() {
  background(50);
  moveSnake();
  checkFood();
  checkCollisions();
  drawSnake();
  drawFood();
  drawScore();
  HAS_GROWN = false;
}

void keyPressed() {
  if (keyCode == UP && direction != DOWNDIR) {
    direction = UPDIR;
  } else if (keyCode == DOWN && direction != UPDIR) {
    direction = DOWNDIR;
  } else if (keyCode == LEFT && direction != RIGHTDIR) {
    direction = LEFTDIR;
  } else if (keyCode == RIGHT && direction != LEFTDIR) {
    direction = RIGHTDIR;
  } else if (keyCode == 'r' || keyCode == 'R'){
    initializeGame();
    loop();
  }
}

void initializeGame() {
  snake = new int[1][2];
  snake[0][0] = BOARD_WIDTH / 2;
  snake[0][1] = BOARD_HEIGHT / 2;
  direction = int(random(4));
  placeFood();
}

void moveSnake() {
  int[] head = snake[0];
  int[] newHead = new int[2];
  if (direction == UPDIR) {
    newHead[0] = head[0];
    newHead[1] = head[1] - 1;
  } else if (direction == DOWNDIR) {
    newHead[0] = head[0];
    newHead[1] = head[1] + 1;
  } else if (direction == LEFTDIR) {
    newHead[0] = head[0] - 1;
    newHead[1] = head[1];
  } else if (direction == RIGHTDIR) {
    newHead[0] = head[0] + 1;
    newHead[1] = head[1];
  }
  for (int i = snake.length - 1; i > 0; i--) {
    snake[i][0] = snake[i - 1][0];
    snake[i][1] = snake[i - 1][1];
  }
  snake[0] = newHead;
}

void checkFood() {
  if (snake[0][0] == food[0] && snake[0][1] == food[1]) {
    int[][] newSnake = new int[snake.length + 1][2];
    newSnake[0][0] = food[0];
    newSnake[0][1] = food[1];
    for (int i = 0; i < snake.length; i++) {
      newSnake[i + 1][0] = snake[i][0];
      newSnake[i + 1][1] = snake[i][1];
    }
    snake = newSnake;
    HAS_GROWN = true;
    placeFood();
    score += 10;
  }
}

void checkCollisions() {
  int[] head = snake[0];
  if (head[0] < 0 || head[0] >= BOARD_WIDTH || head[1] < 0 || head[1] >= BOARD_HEIGHT) {
    endGame();
  }
  if (!HAS_GROWN){
    for (int i = 1; i < snake.length; i++) {
      if (head[0] == snake[i][0] && head[1] == snake[i][1]) {
        endGame();
      }
    }
  }
}

void endGame(){
  textSize(32);
  textAlign(CENTER);
  fill(255);
  text("Game over!\nPress R to Restart", width / 2, height / 2);
  noLoop();
}

void placeFood() {
  food[0] = (int) random(1, BOARD_WIDTH-1);
  food[1] = (int) random(1, BOARD_HEIGHT-1);
}

void drawSnake() {
  fill(255);
  for (int[] segment : snake) {
    rect(segment[0] * BLOCK_SIZE, segment[1] * BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE);
  }
}

void drawFood() {
  fill(255, 0, 0);
  rect(food[0] * BLOCK_SIZE, food[1] * BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE);
}

void drawScore() {
  textSize(16);
  textAlign(LEFT);
  fill(255);
  text("Score: " + score, 10, 20);
}
