int bricksPerRow = 10;
int numRows = 5;
int brickWidth = 50;
int brickHeight = 20;
int brickGap = 10;
int brickColor = color(255, 204, 0);

int ballSize = 20;
int ballColor = color(255, 255, 255);
float ballSpeed = 5.0;

int paddleWidth = 100;
int paddleHeight = 10;
int paddleColor = color(255, 255, 255);
float paddleSpeed = 8.0;

int score = 0;

float ballX, ballY;
float ballVelX, ballVelY;

float paddleX, paddleY;

int[][] bricks;

void setup() {
  size(500, 600);
  colorMode(HSB, 255);
  resetGame();
}

void draw() {
  background(0);
  
  for (int i = 0; i < numRows; i++) {
    for (int j = 0; j < bricksPerRow; j++) {
      if (bricks[i][j] == 1) {
        int brickX = j * (brickWidth + brickGap) + brickGap;
        int brickY = i * (brickHeight + brickGap) + brickGap;
        float hue = map(i+j, 0, numRows+bricksPerRow, 0, 255);
        float saturation = 255;
        float brightness = 200;
        fill(hue, saturation, brightness);
        rect(brickX, brickY, brickWidth, brickHeight);
      }
    }
  }
  
  fill(paddleColor);
  rect(paddleX, paddleY, paddleWidth, paddleHeight);
  
  if (keyPressed && (key == 'a' || key == 'A') && paddleX > 0) {
    paddleX -= paddleSpeed;
  } else if (keyPressed && (key == 'd' || key == 'D') && paddleX + paddleWidth < width) {
    paddleX += paddleSpeed;
  }
  
  fill(ballColor);
  ellipse(ballX, ballY, ballSize, ballSize);
  
  ballX += ballVelX;
  ballY += ballVelY;
  
  if (ballX < ballSize/2 || ballX > width - ballSize/2) {
    ballVelX = -ballVelX;
  }
  if (ballY < ballSize/2) {
    ballVelY = -ballVelY;
  }
  
  if (ballY + ballSize/2 >= paddleY && ballX >= paddleX && ballX <= paddleX + paddleWidth) {
    ballVelY = -ballVelY;
  }
  
  int row = int((ballY - ballSize/2) / (brickHeight + brickGap));
  int col = int(ballX / (brickWidth + brickGap));
  if (row >= 0 && row < numRows && col >= 0 && col < bricksPerRow && bricks[row][col] == 1) {
    bricks[row][col] = 0;
    ballVelY = -ballVelY;
    score += 10;
  }
  
  if (ballY > height) {
    resetGame();
  }
  
  if (score == numRows * bricksPerRow * 10) {
    textSize(32);
    fill(255);
    text("You Win!", width/2 - 80, height/2);
    noLoop();
  }
  
  textSize(20);
  fill(255);
  text("Score: " + score, 20, height - 30);
}

void resetGame() {
  ballX = width/2;
  ballY = height/2;
  ballVelX = ballSpeed;
  ballVelY = -ballSpeed;
  paddleX = width/2 - paddleWidth/2;
  paddleY = height - 50;
  
  bricks = new int[numRows][bricksPerRow];
  for (int i = 0; i < numRows; i++) {
    for (int j = 0; j < bricksPerRow; j++) {
      bricks[i][j] = 1;
    }
  }
  
  score = 0;
}
