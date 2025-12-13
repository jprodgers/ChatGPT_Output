// Sandpile cellular automaton with configurable resolution, palette, and exporting
// Single-file Processing sketch

int controlWidth = 260;         // Left panel width
int sandAreaSize;               // Square drawing area size
int cellSize = 4;               // Pixel size per sand cell
int cols, rows;                 // Grid dimensions
int threshold = 4;              // Topple threshold
int levels = 6;                 // Number of visualization levels

int[][] grid;
int[][] bufferGrid;

int updatesPerDraw = 1;         // Steps per frame
float targetFPS = 30;           // Target updates per second
boolean pauseUpdates = false;   // Toggle stepping

boolean autoExport = false;     // Save every frame automatically
int exportCounter = 0;          // Index for saved frames
String exportBase = "export/frame";

color[] palette;
int selectedLevel = 0;          // Palette index being edited
float pickerHue = 0;            // HSB color picker values
float pickerSat = 200;
float pickerBri = 255;
int paletteSwatchY = 0;         // Layout bookkeeping for clicks
int paletteTopY = 0;
int sliderStartY = 0;

void settings() {
  size(1200, 800); // Default size; can be changed at runtime
}

void setup() {
  surface.setResizable(true);
  surface.setTitle("Sandpile Automaton");
  computeLayout();
  initializeGrid();
  palette = buildPalette(levels);
  syncPickerWithColor(palette[selectedLevel]);
  frameRate(targetFPS);
}

void computeLayout() {
  sandAreaSize = min(height, width - controlWidth);
  sandAreaSize = max(10, sandAreaSize);
}

void initializeGrid() {
  cols = max(1, sandAreaSize / cellSize);
  rows = max(1, sandAreaSize / cellSize);
  grid = new int[cols][rows];
  bufferGrid = new int[cols][rows];
}

void draw() {
  computeLayout();
  if (grid == null || grid.length != max(1, sandAreaSize / cellSize) || grid[0].length != max(1, sandAreaSize / cellSize)) {
    initializeGrid();
  }

  background(0);
  drawControls();

  if (!pauseUpdates) {
    for (int i = 0; i < updatesPerDraw; i++) {
      updateSandpile();
    }
  }

  drawSand();

  if (autoExport) {
    saveFrame(exportBase + nf(exportCounter++, 5) + ".png");
  }
}

void updateSandpile() {
  // Clear buffer
  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      bufferGrid[x][y] = 0;
    }
  }

  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      int grains = grid[x][y];
      if (grains >= threshold) {
        int toppleCount = grains / threshold;
        bufferGrid[x][y] -= toppleCount * threshold;
        if (x > 0) bufferGrid[x - 1][y] += toppleCount;
        if (x < cols - 1) bufferGrid[x + 1][y] += toppleCount;
        if (y > 0) bufferGrid[x][y - 1] += toppleCount;
        if (y < rows - 1) bufferGrid[x][y + 1] += toppleCount;
      }
    }
  }

  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      grid[x][y] += bufferGrid[x][y];
    }
  }
}

void drawSand() {
  int xOffset = controlWidth;
  int yOffset = (height - sandAreaSize) / 2;
  noStroke();
  fill(0);
  rect(xOffset, yOffset, sandAreaSize, sandAreaSize);

  for (int x = 0; x < cols; x++) {
    for (int y = 0; y < rows; y++) {
      int value = grid[x][y];
      if (value > 0) {
        int levelIndex = constrain(value % levels, 0, levels - 1);
        fill(palette[levelIndex]);
        rect(xOffset + x * cellSize, yOffset + y * cellSize, cellSize, cellSize);
      }
    }
  }
  noFill();
  stroke(80);
  rect(xOffset, yOffset, sandAreaSize, sandAreaSize);
}

void drawControls() {
  fill(0);
  noStroke();
  rect(0, 0, controlWidth, height);

  fill(255);
  textAlign(LEFT, TOP);
  textSize(14);
  int y = 10;
  int lineHeight = 18;

  text("Sandpile Controls", 10, y);
  y += lineHeight * 2;

  text("FPS (+/-): " + nf(targetFPS, 0, 1), 10, y); y += lineHeight;
  text("Steps/frame (</>): " + updatesPerDraw, 10, y); y += lineHeight;
  text("Cell size ([/]): " + cellSize + " px", 10, y); y += lineHeight;
  text("Levels (L/l): " + levels, 10, y); y += lineHeight;
  text("Auto export (A): " + (autoExport ? "on" : "off"), 10, y); y += lineHeight;
  text("Pause (Space): " + (pauseUpdates ? "yes" : "no"), 10, y); y += lineHeight;
  text("Click: add sand", 10, y); y += lineHeight;
  text("E: export frame", 10, y); y += lineHeight;
  text("R: reset grid", 10, y); y += lineHeight;
  text("Add 1000 grains (G)", 10, y); y += lineHeight * 2;

  paletteSwatchY = y;
  drawPaletteSwatches(10, y);
  y = paletteSwatchY;

  sliderStartY = y + lineHeight;
  drawColorPicker(10, sliderStartY);
}

void drawPaletteSwatches(int startX, int startY) {
  int swatchSize = 20;
  int gap = 6;
  int perRow = max(1, (controlWidth - startX * 2) / (swatchSize + gap));
  int x = startX;
  int y = startY;

  text("Palette (click to edit):", startX, y);
  y += 22;
  paletteTopY = y;

  for (int i = 0; i < levels; i++) {
    if ((i % perRow == 0) && i != 0) {
      x = startX;
      y += swatchSize + gap;
    }

    fill(palette[i]);
    stroke(255);
    rect(x, y, swatchSize, swatchSize);

    if (i == selectedLevel) {
      noFill();
      stroke(255, 220, 0);
      strokeWeight(2);
      rect(x - 2, y - 2, swatchSize + 4, swatchSize + 4);
      strokeWeight(1);
    }

    x += swatchSize + gap;
  }

  paletteSwatchY = y + swatchSize;
}

void drawColorPicker(int startX, int startY) {
  int sliderWidth = controlWidth - startX * 2;
  int sliderGap = 30;

  fill(255);
  text("Color picker (HSB)", startX, startY);
  startY += 16;

  pickerHue = drawSlider("Hue", startX, startY, sliderWidth, pickerHue, 255, color(180, 255, 255));
  startY += sliderGap;
  pickerSat = drawSlider("Sat", startX, startY, sliderWidth, pickerSat, 255, color(120, 255, 255));
  startY += sliderGap;
  pickerBri = drawSlider("Bri", startX, startY, sliderWidth, pickerBri, 255, color(60, 255, 255));

  palette[selectedLevel] = colorFromHSB(pickerHue, pickerSat, pickerBri);
}

float drawSlider(String label, int x, int y, int w, float value, float maxVal, color accent) {
  int barHeight = 12;
  fill(200);
  text(label + ": " + nf(value, 0, 0), x, y - 2);

  int barY = y + 6;
  fill(60);
  noStroke();
  rect(x, barY, w, barHeight, 4);

  float handleX = constrain(map(value, 0, maxVal, 0, w), 0, w);
  fill(accent);
  rect(x, barY, handleX, barHeight, 4);

  stroke(255);
  line(x + handleX, barY - 3, x + handleX, barY + barHeight + 3);

  if (mousePressed && mouseX >= x && mouseX <= x + w && mouseY >= barY && mouseY <= barY + barHeight) {
    value = map(mouseX, x, x + w, 0, maxVal);
  }

  return constrain(value, 0, maxVal);
}

void mousePressed() {
  if (mouseX < controlWidth) {
    if (handleControlClick(mouseX, mouseY)) {
      return;
    }
  }

  if (mouseX >= controlWidth && mouseX < controlWidth + sandAreaSize) {
    int x = (mouseX - controlWidth) / cellSize;
    int yOffset = (height - sandAreaSize) / 2;
    int y = (mouseY - yOffset) / cellSize;
    if (x >= 0 && x < cols && y >= 0 && y < rows) {
      grid[x][y] += 1000;
    }
  }
}

void keyPressed() {
  if (key == '+') {
    targetFPS = min(240, targetFPS + 5);
    frameRate(targetFPS);
  } else if (key == '-') {
    targetFPS = max(1, targetFPS - 5);
    frameRate(targetFPS);
  } else if (key == '>') {
    updatesPerDraw = min(100000, updatesPerDraw * 2);
  } else if (key == '<') {
    updatesPerDraw = max(1, updatesPerDraw / 2);
  } else if (key == '[') {
    cellSize = max(1, cellSize - 1);
    initializeGrid();
  } else if (key == ']') {
    cellSize = min(sandAreaSize, cellSize + 1);
    initializeGrid();
  } else if (key == ' ') {
    pauseUpdates = !pauseUpdates;
  } else if (key == 'E' || key == 'e') {
    saveFrame(exportBase + nf(exportCounter++, 5) + ".png");
  } else if (key == 'R' || key == 'r') {
    initializeGrid();
  } else if (key == 'A' || key == 'a') {
    autoExport = !autoExport;
  } else if (key == 'G' || key == 'g') {
    dropCenter(1000);
  } else if (key == 'L') {
    levels = min(64, levels + 1);
    palette = buildPalette(levels);
    selectedLevel = min(selectedLevel, levels - 1);
    syncPickerWithColor(palette[selectedLevel]);
  } else if (key == 'l') {
    levels = max(2, levels - 1);
    palette = buildPalette(levels);
    selectedLevel = min(selectedLevel, levels - 1);
    syncPickerWithColor(palette[selectedLevel]);
  }
}

void dropCenter(int amount) {
  int cx = cols / 2;
  int cy = rows / 2;
  if (cx >= 0 && cy >= 0 && cx < cols && cy < rows) {
    grid[cx][cy] += amount;
  }
}

color[] buildPalette(int count) {
  color[] colors = new color[count];
  for (int i = 0; i < count; i++) {
    float t = map(i, 0, count - 1, 0, 1);
    colors[i] = rainbowColor(t);
  }
  return colors;
}

color rainbowColor(float t) {
  // Generates a rainbow gradient using HSV-like interpolation
  float hue = t * 255;
  colorMode(HSB, 255);
  color c = color(hue, 200, 255);
  colorMode(RGB, 255);
  return c;
}

color colorFromHSB(float h, float s, float b) {
  colorMode(HSB, 255);
  color c = color(h, s, b);
  colorMode(RGB, 255);
  return c;
}

void syncPickerWithColor(color c) {
  colorMode(HSB, 255);
  pickerHue = hue(c);
  pickerSat = saturation(c);
  pickerBri = brightness(c);
  colorMode(RGB, 255);
}

boolean handleControlClick(int mx, int my) {
  int swatchSize = 20;
  int gap = 6;
  int startX = 10;
  int perRow = max(1, (controlWidth - startX * 2) / (swatchSize + gap));

  int x = startX;
  int y = paletteTopY;

  for (int i = 0; i < levels; i++) {
    if (mx >= x && mx <= x + swatchSize && my >= y && my <= y + swatchSize) {
      selectedLevel = i;
      syncPickerWithColor(palette[selectedLevel]);
      return true;
    }

    x += swatchSize + gap;
    if ((i + 1) % perRow == 0) {
      x = startX;
      y += swatchSize + gap;
    }
  }

  return false;
}
