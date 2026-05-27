import processing.sound.*;

Mech p1, p2;
ArrayList<Bullet> bullets;
ArrayList<Particle> particles;
ArrayList<Wall> walls;
ArrayList<Perk> perks;
ArrayList<Mine> mines;
ArrayList<Trail> trails;

TriOsc shootOsc;
WhiteNoise explodeNoise;
Env env;

boolean[] keys = new boolean[256];

float globalBulletSpeed = 5.0;
int score1 = 0;
int score2 = 0;
boolean gameOver = false;
boolean requestReset = false;
String winMessage = "";

// Screen shake
float shakeX = 0, shakeY = 0;
float shakeIntensity = 0;

// War zone environment
float[][] craters;
int numCraters = 18;
float[][] ash;
int numAsh = 120;

// Scanline animation
int scanlineOffset = 0;

void setup() {
  size(800, 600);
  rectMode(CENTER);
  textAlign(CENTER, CENTER);

  craters = new float[numCraters][3];
  for (int i = 0; i < numCraters; i++) {
    craters[i][0] = random(width);
    craters[i][1] = random(height);
    craters[i][2] = random(30, 90);
  }

  ash = new float[numAsh][3];
  for (int i = 0; i < numAsh; i++) {
    ash[i][0] = random(width);
    ash[i][1] = random(height);
    ash[i][2] = random(0.5, 2.5);
  }

  bullets  = new ArrayList<Bullet>();
  particles= new ArrayList<Particle>();
  walls    = new ArrayList<Wall>();
  perks    = new ArrayList<Perk>();
  mines    = new ArrayList<Mine>();
  trails   = new ArrayList<Trail>();

  walls.add(new Wall(width/2,         150,          200, 25));
  walls.add(new Wall(width/2,         height - 150, 200, 25));
  walls.add(new Wall(200,             height/2,      25, 200));
  walls.add(new Wall(width - 200,     height/2,      25, 200));
  walls.add(new Wall(width/2,         height/2,      25, 150));

  p1 = new Mech(100,         height/2, 0,  color(0, 255, 100), 'w','s','a','d','f','g');
  p2 = new Mech(width - 100, height/2, PI, color(255, 60, 60),  UP, DOWN, LEFT, RIGHT, 'l','k');

  shootOsc     = new TriOsc(this);
  explodeNoise = new WhiteNoise(this);
  env          = new Env(this);
}

void draw() {
  if (shakeIntensity > 0.1) {
    shakeX = random(-shakeIntensity, shakeIntensity);
    shakeY = random(-shakeIntensity, shakeIntensity);
    shakeIntensity *= 0.82;
  } else { shakeX = 0; shakeY = 0; shakeIntensity = 0; }

  drawBattlefield();

  if (gameOver) {
    drawGameOver();
    drawScanlines();
    return;
  }

  translate(shakeX, shakeY);

  drawUI();

  for (Wall w : walls) { w.update(); w.display(); }

  for (int i = trails.size() - 1; i >= 0; i--) {
    Trail t = trails.get(i);
    t.update(); t.display();
    if (t.isDead()) trails.remove(i);
  }

  for (int i = perks.size() - 1; i >= 0; i--) {
    Perk p = perks.get(i);
    p.display();
    if (dist(p.x, p.y, p1.x, p1.y) < 25) { p1.applyPerk(p.type); perks.remove(i); }
    else if (dist(p.x, p.y, p2.x, p2.y) < 25) { p2.applyPerk(p.type); perks.remove(i); }
  }

  for (int i = mines.size() - 1; i >= 0; i--) {
    Mine m = mines.get(i);
    m.update();
    if (m.checkDetonation(p1, p2)) {
      explode(m.x, m.y, color(255, 110, 30));
      mines.remove(i);
    }
  }

  globalBulletSpeed += 0.001;

  p1.update(); p1.display();
  p2.update(); p2.display();

  for (int i = bullets.size() - 1; i >= 0; i--) {
    Bullet b = bullets.get(i);
    b.update();
    b.display();

    trails.add(new Trail(b.x, b.y, b.getBulletColor(), 9));

    boolean hitWall = false;
    for (Wall w : walls) {
      if (w.collidesWithRect(b.x, b.y, 6, 6)) {
        if (b.piercing) {
        } else if (b.bouncing) {
          float ox = (w.w/2 + 3) - abs(b.x - w.x);
          float oy = (w.h/2 + 3) - abs(b.y - w.y);
          if (ox < oy) { b.vx *= -1; b.x += (b.x > w.x ? ox : -ox); }
          else         { b.vy *= -1; b.y += (b.y > w.y ? oy : -oy); }
          for (int s = 0; s < 6; s++)
            particles.add(new Particle(b.x, b.y, color(150, 255, 150), 0.7));
        } else {
          hitWall = true;
          for (int s = 0; s < 8; s++)
            particles.add(new Particle(b.x, b.y, color(100, 140, 255), 0.8));
        }
        break;
      }
    }
    if (hitWall) { bullets.remove(i); continue; }

    if (b.owner != p1 && dist(b.x, b.y, p1.x, p1.y) < 20) { processHit(p1); bullets.remove(i); continue; }
    if (b.owner != p2 && dist(b.x, b.y, p2.x, p2.y) < 20) { processHit(p2); bullets.remove(i); continue; }

    if (b.isOffScreen() && !b.bouncing) bullets.remove(i);
  }

  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update(); p.display();
    if (p.isDead()) particles.remove(i);
  }

  drawScanlines();

  if (requestReset) { resetRound(); requestReset = false; }
}

void drawBattlefield() {
  background(45, 38, 28);
  
  noStroke();
  for (int i = 0; i < numCraters; i++) {
    fill(28, 22, 16, 180);
    ellipse(craters[i][0], craters[i][1], craters[i][2], craters[i][2] * 0.85);
    fill(18, 14, 10, 220);
    ellipse(craters[i][0], craters[i][1] + craters[i][2]*0.1, craters[i][2]*0.7, craters[i][2]*0.6);
  }
  
  for (int i = 0; i < numAsh; i++) {
    ash[i][0] += ash[i][2] * 0.7;
    ash[i][1] += ash[i][2] * 1.2;
    if (ash[i][0] > width) ash[i][0] = 0;
    if (ash[i][1] > height) ash[i][1] = 0;
    
    fill(80, 75, 70, 160);
    rect(ash[i][0], ash[i][1], ash[i][2]*1.5, ash[i][2]*1.5);
  }
}

void drawScanlines() {
  scanlineOffset = (scanlineOffset + 1) % 4;
  for (int y = scanlineOffset; y < height; y += 4) {
    stroke(0, 0, 0, 45);
    strokeWeight(1);
    line(0, y, width, y);
  }
  noFill();
  for (int i = 0; i < 10; i++) {
    stroke(0, 0, 0, 60 - i * 5);
    strokeWeight(i * 5);
    rect(width/2, height/2, width - i*8, height - i*8);
  }
}

void drawGameOver() {
  float pulse = 0.5 + 0.5 * sin(frameCount * 0.06);
  textSize(52);
  for (int i = 8; i > 0; i--) {
    fill(255, 200, 0, 15 + 12 * pulse);
    text(winMessage, width/2 + random(-i, i), height/2 - 20 + random(-i, i));
  }
  fill(255, 220, 50);
  text(winMessage, width/2, height/2 - 20);

  textSize(20);
  fill(200, 200, 200, 140 + 115 * pulse);
  text("Press  R  to restart", width/2, height/2 + 45);
}

void processHit(Mech p) {
  if (p.hasShield) {
    p.hasShield = false;
    for (int i = 0; i < 24; i++)
      particles.add(new Particle(p.x, p.y, color(0, 255, 255), 1.1));
    shakeIntensity = 4;
  } else {
    p.hp--;
    p.hitFlash = 12;
    shakeIntensity = 6;
  }
  perks.add(new Perk(p.x + random(-50, 50), p.y + random(-50, 50), int(random(5))));
  checkDeath();
}

void drawUI() {
  textSize(50);
  for (int i = 4; i > 0; i--) {
    fill(0, 255, 100, 18 * i);
    text(score1, 100 + random(-i,i), 48 + random(-i,i));
  }
  fill(0, 255, 100);
  text(score1, 100, 48);

  for (int i = 4; i > 0; i--) {
    fill(255, 60, 60, 18 * i);
    text(score2, width - 100 + random(-i,i), 48 + random(-i,i));
  }
  fill(255, 60, 60);
  text(score2, width - 100, 48);

  for (int i = 0; i < 5; i++) {
    color on1 = color(0, 255, 100); color off1 = color(0, 55, 25);
    color on2 = color(255, 60, 60); color off2 = color(70, 15, 15);
    noStroke();
    fill(i < score1 ? on1 : off1); ellipse(62 + i * 18, 78, 11, 11);
    fill(i < score2 ? on2 : off2); ellipse(width - 62 - i * 18, 78, 11, 11);
  }

  textSize(13);
  fill(255, 165, 0);
  text("MINES " + p1.mineCount, 100, 97);
  text("MINES " + p2.mineCount, width - 100, 97);

  textSize(11);
  fill(80, 80, 180, 160);
  text("PROJ SPD  " + nf(globalBulletSpeed, 1, 1), width/2, 18);

  stroke(40, 40, 100, 90);
  strokeWeight(1);
  line(0, 112, width, 112);
}

void checkDeath() {
  boolean roundEnded = false;
  if (p1.hp <= 0) { explode(p1.x, p1.y, p1.c); shakeIntensity = 14; score2++; roundEnded = true; }
  else if (p2.hp <= 0) { explode(p2.x, p2.y, p2.c); shakeIntensity = 14; score1++; roundEnded = true; }

  if (roundEnded) {
    if (score1 >= 5) { winMessage = "PLAYER 1  WINS!"; gameOver = true; }
    else if (score2 >= 5) { winMessage = "PLAYER 2  WINS!"; gameOver = true; }
    else requestReset = true;
  }
}

void resetRound() {
  p1.reset(p1.startX, p1.startY, p1.startAngle);
  p2.reset(p2.startX, p2.startY, p2.startAngle);
  bullets.clear(); perks.clear(); mines.clear(); trails.clear();
  globalBulletSpeed = 5.0;
}

void restartGame() {
  score1 = 0; score2 = 0; gameOver = false; requestReset = false;
  resetRound();
}

void explode(float x, float y, color c) {
  playExplodeSound();
  for (int i = 0; i < 55; i++) particles.add(new Particle(x, y, c,          1.0));
  for (int i = 0; i < 22; i++) particles.add(new Particle(x, y, color(255,255,200), 1.6));
  for (int i = 0; i < 18; i++) particles.add(new Particle(x, y, color(255,180, 40), 2.2));
}

void keyPressed() {
  if (keyCode < 256) keys[keyCode] = true;
  if (key   < 256)   keys[Character.toLowerCase(key)] = true;
  if (!gameOver) {
    if (key == 'f' || key == 'F') p1.shoot();
    if (key == 'l' || key == 'L') p2.shoot();
  } else {
    if (key == 'r' || key == 'R') restartGame();
  }
}

void keyReleased() {
  if (keyCode < 256) keys[keyCode] = false;
  if (key   < 256)   keys[Character.toLowerCase(key)] = false;
}

void playShootSound() {
  shootOsc.play();
  env.play(shootOsc, 0.01, 0.1, 0.5, 0.1);
}
void playExplodeSound() {
  explodeNoise.play();
  env.play(explodeNoise, 0.01, 0.3, 0.8, 0.4);
}

class Trail {
  float x, y;
  color c;
  float life, maxLife, sz;
  Trail(float x, float y, color c, float sz) {
    this.x = x; this.y = y; this.c = c; this.sz = sz;
    maxLife = 10; life = maxLife;
  }
  void update() { life--; }
  void display() {
    float a  = map(life, 0, maxLife, 0, 160);
    float s  = map(life, 0, maxLife, 1, sz);
    noStroke();
    fill(red(c), green(c), blue(c), a * 0.35);
    rect(x, y, s * 2.2, s * 2.2);
    fill(red(c), green(c), blue(c), a);
    rect(x, y, s, s);
  }
  boolean isDead() { return life <= 0; }
}

class Wall {
  float x, y, w, h, vx, vy, phase;
  Wall(float x, float y, float w, float h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    phase = random(TWO_PI);
    setRandomDir();
  }
  void setRandomDir() {
    float a = random(TWO_PI), spd = random(0.5, 1.5);
    vx = cos(a) * spd; vy = sin(a) * spd;
  }
  void update() {
    if (frameCount % 120 == 0) setRandomDir();
    x += vx; y += vy;
    if (x - w/2 < 0 || x + w/2 > width)  { vx *= -1; x = constrain(x, w/2, width  - w/2); }
    if (y - h/2 < 0 || y + h/2 > height) { vy *= -1; y = constrain(y, h/2, height - h/2); }
  }
  void display() {
    noStroke();
    fill(65, 60, 55);
    rect(x, y, w, h);
    fill(45, 40, 35);
    rect(x, y, w - 8, h - 8);
    fill(130, 110, 40, 140);
    float stripeW = w * 0.6;
    float stripeH = h * 0.6;
    rect(x, y, stripeW, stripeH);
  }
  boolean collidesWithRect(float rx, float ry, float rw, float rh) {
    return (x - w/2 < rx + rw/2) && (x + w/2 > rx - rw/2) &&
           (y - h/2 < ry + rh/2) && (y + h/2 > ry - rh/2);
  }
}

class Mech {
  float x, y, angle, startX, startY, startAngle;
  color c;
  int up, down, left, right, shootKey, mineKey;
  int cooldown = 0, mineCooldown = 0, hp = 3;
  boolean hasShield = false, piercing = false, fastSpin = false, bouncingBullets = false;
  int mineCount = 0;
  float legCycle = 0;
  int hitFlash = 0;

  Mech(float x, float y, float angle, color c,
       int up, int down, int left, int right, int shootKey, int mineKey) {
    this.startX = x; this.startY = y; this.startAngle = angle; this.c = c;
    this.up = up; this.down = down; this.left = left; this.right = right;
    this.shootKey = shootKey; this.mineKey = mineKey;
    reset(x, y, angle);
  }

  void reset(float x, float y, float angle) {
    this.x = x; this.y = y; this.angle = angle;
    hp = 3; hasShield = false; piercing = false;
    mineCount = 0; fastSpin = false; bouncingBullets = false; hitFlash = 0;
  }

  void applyPerk(int t) {
    if (t == 0) hasShield = true;
    if (t == 1) piercing = true;
    if (t == 2) mineCount++;
    if (t == 3) fastSpin = true;
    if (t == 4) bouncingBullets = true;
  }

  color getBulletColor() {
    if (piercing)         return color(255, 0, 255);
    if (bouncingBullets)  return color(150, 255, 150);
    return color(0, 255, 255);
  }

  void update() {
    float rot = fastSpin ? 0.10 : 0.05;
    if (keys[left])  angle -= rot;
    if (keys[right]) angle += rot;

    boolean moving = false;
    float nx = x, ny = y;
    if (keys[up])   { nx += cos(angle)*2; ny += sin(angle)*2; moving = true; }
    if (keys[down]) { nx -= cos(angle)*2; ny -= sin(angle)*2; moving = true; }
    if (moving) legCycle += 0.22;

    boolean col = false;
    for (Wall w : walls) if (w.collidesWithRect(nx, ny, 30, 30)) { col = true; break; }
    if (!col) { x = nx; y = ny; }
    x = constrain(x, 20, width  - 20);
    y = constrain(y, 20, height - 20);

    if (cooldown     > 0) cooldown--;
    if (mineCooldown > 0) mineCooldown--;
    if (hitFlash     > 0) hitFlash--;

    if (keys[mineKey] && mineCount > 0 && mineCooldown == 0) {
      mines.add(new Mine(x, y, this));
      mineCount--;
      mineCooldown = 60;
    }
  }

  void shoot() {
    if (cooldown == 0 && hp > 0) {
      bullets.add(new Bullet(x + cos(angle)*25, y + sin(angle)*25,
                             angle, this, globalBulletSpeed, piercing, bouncingBullets));
      playShootSound();
      cooldown = 30;
      for (int i = 0; i < 6; i++)
        particles.add(new Particle(x + cos(angle)*28, y + sin(angle)*28,
                                   color(255, 255, 140), 1.3));
    }
  }

  void display() {
    color dc = (hitFlash > 0 && hitFlash % 4 < 2) ? color(255,255,255) : c;

    pushMatrix();
    translate(x, y);

    if (hasShield) {
      float sp = 0.5 + 0.5 * sin(frameCount * 0.12);
      noFill();
      for (int i = 4; i > 0; i--) {
        stroke(0, 200 + 55 * sp, 255, 55 * (i / 4.0));
        strokeWeight(i * 2.5);
        ellipse(0, 0, 54 + i * 5, 54 + i * 5);
      }
      stroke(0, 255, 255, 210);
      strokeWeight(1.5);
      ellipse(0, 0, 54, 54);
    }

    rotate(angle);
    noStroke();

    for (int i = 3; i > 0; i--) {
      fill(red(dc), green(dc), blue(dc), 18 * (i / 3.0));
      rect(0, 0, 24 + i*6, 32 + i*6);
    }

    float lo = sin(legCycle) * 3.5;
    fill(red(dc)*0.65, green(dc)*0.65, blue(dc)*0.65);
    rect(-10, -18 + lo,  8, 10);
    rect(-10,  18 - lo,  8, 10);

    fill(dc);
    rect(0, 0, 22, 28);

    fill(red(dc)*0.4, green(dc)*0.4, blue(dc)*0.4);
    rect(2, 0, 13, 18);

    fill(170, 225, 255, 220);
    rect(4, 0, 6, 10);

    fill(dc);
    rect(5, -19, 24, 7);
    rect(5,  19, 24, 7);
    rect(2, -23, 11, 5);
    rect(2,  23, 11, 5);

    fill(red(dc)*0.65, green(dc)*0.65, blue(dc)*0.65);
    rect(18, 0, 18, 5);

    if (cooldown == 0) {
      float cg = 0.45 + 0.55 * sin(frameCount * 0.25);
      fill(red(dc), green(dc), blue(dc), 160 * cg);
      ellipse(28, 0, 10, 10);
      fill(255, 255, 255, 100 * cg);
      ellipse(28, 0, 4, 4);
    }

    fill(red(dc)*0.55, green(dc)*0.55, blue(dc)*0.55);
    rect(-13, -8, 9, 9);
    rect(-13,  8, 9, 9);

    float fl = 4 + 3.5 * sin(frameCount * 0.35);
    fill(255, 90 + 80 * sin(frameCount * 0.5), 0, 190);
    rect(-19, -8, fl, 5);
    rect(-19,  8, fl, 5);
    fill(255, 220, 80, 120);
    rect(-20, -8, fl * 0.5, 3);
    rect(-20,  8, fl * 0.5, 3);

    popMatrix();

    pushMatrix();
    translate(x, y - 38);
    noStroke();
    fill(30, 30, 30);
    rect(0, 0, 34, 6);
    float hf = hp / 3.0;
    color hc = (hp == 3) ? color(0, 255, 80) : (hp == 2) ? color(255, 200, 0) : color(255, 45, 45);
    fill(hc);
    rect(-17 + 17*hf, 0, 34*hf, 6);
    noFill();
    stroke(hc, 120);
    strokeWeight(1);
    rect(0, 0, 34, 6);

    noStroke();
    int px = -22;
    if (hasShield)       { fill(0,255,255);     rect(px, -14, 9, 9); textSize(7); fill(0); text("S", px, -15); px += 12; }
    if (piercing)        { fill(255,0,255);      rect(px, -14, 9, 9); textSize(7); fill(0); text("P", px, -15); px += 12; }
    if (bouncingBullets) { fill(150,255,150);    rect(px, -14, 9, 9); textSize(7); fill(0); text("R", px, -15); px += 12; }
    if (fastSpin)        { fill(255,255,0);      rect(px, -14, 9, 9); textSize(7); fill(0); text("G", px, -15); }
    popMatrix();
  }
}

class Mine {
  float x, y;
  Mech owner;
  int armTimer = 60;
  Mine(float x, float y, Mech owner) { this.x = x; this.y = y; this.owner = owner; }

  void update() {
    if (armTimer > 0) armTimer--;
    noStroke();
    float pulse = 0.5 + 0.5 * sin(frameCount * 0.12);

    for (int i = 3; i > 0; i--) {
      fill(255, 80, 0, 28 * pulse);
      ellipse(x, y, 12 + i*6, 12 + i*6);
    }
    fill(200, 55, 0);
    ellipse(x, y, 13, 13);
    fill(255, 80, 0, 180);
    ellipse(x, y, 7, 7);

    if (armTimer <= 0) {
      if (frameCount % 20 < 10) { fill(255, 255, 0); ellipse(x, y, 6, 6); }
      noFill();
      stroke(255, 100, 0, 50 + 40 * pulse);
      strokeWeight(1);
      float ring = 60 + 12 * sin(frameCount * 0.1);
      ellipse(x, y, ring, ring);
    }
  }

  boolean checkDetonation(Mech q1, Mech q2) {
    if (armTimer > 0) return false;
    if (dist(x, y, q1.x, q1.y) < 30) { processHit(q1); return true; }
    if (dist(x, y, q2.x, q2.y) < 30) { processHit(q2); return true; }
    return false;
  }
}

class Perk {
  float x, y, phase;
  int type;
  String[] labels = {"SH","PI","MN","GR","RI"};
  color[] cols = {
    color(0, 255, 255),
    color(255, 0, 255),
    color(255, 165, 0),
    color(255, 255, 0),
    color(140, 255, 140)
  };

  Perk(float x, float y, int type) {
    this.x = constrain(x, 25, width-25);
    this.y = constrain(y, 25, height-25);
    this.type = type;
    this.phase = random(TWO_PI);
  }

  void display() {
    float pulse = 0.45 + 0.55 * sin(frameCount * 0.08 + phase);
    float bob   = sin(frameCount * 0.07 + phase) * 3.5;
    color c = cols[type];

    noStroke();
    for (int i = 5; i > 0; i--) {
      fill(red(c), green(c), blue(c), 20 * pulse * (i / 5.0));
      rect(x, y + bob, 30 + i*5, 30 + i*5);
    }
    fill(red(c)*0.18, green(c)*0.18, blue(c)*0.18);
    rect(x, y + bob, 28, 28);
    stroke(c); strokeWeight(1.8); noFill();
    rect(x, y + bob, 26, 26);
    noStroke(); fill(c);
    textSize(10);
    text(labels[type], x, y + bob - 1);
  }
}

class Bullet {
  float x, y, vx, vy;
  Mech owner;
  boolean piercing, bouncing;

  Bullet(float x, float y, float angle, Mech owner, float spd, boolean piercing, boolean bouncing) {
    this.x = x; this.y = y;
    vx = cos(angle)*spd; vy = sin(angle)*spd;
    this.owner = owner; this.piercing = piercing; this.bouncing = bouncing;
  }

  color getBulletColor() {
    if (piercing)  return color(255, 0, 255);
    if (bouncing)  return color(150, 255, 150);
    return color(0, 255, 255);
  }

  void update() {
    x += vx; y += vy;
    if (bouncing) {
      if (x < 0 || x > width)  vx *= -1;
      if (y < 0 || y > height) vy *= -1;
      x = constrain(x, 0, width);
      y = constrain(y, 0, height);
    }
  }

  void display() {
    color c = getBulletColor();
    noStroke();
    for (int i = 4; i > 0; i--) {
      fill(red(c), green(c), blue(c), 55 * (i / 4.0));
      rect(x, y, 6 + i*4, 6 + i*4);
    }
    fill(c);
    rect(x, y, 6, 6);
    fill(255, 255, 255, 210);
    rect(x, y, 2, 2);
  }

  boolean isOffScreen() {
    return x < 0 || x > width || y < 0 || y > height;
  }
}

class Particle {
  float x, y, vx, vy, size;
  int life, maxLife;
  color c;

  Particle(float x, float y, color c, float speedMult) {
    this.x = x; this.y = y; this.c = c;
    float a = random(TWO_PI), spd = random(1, 5) * speedMult;
    vx = cos(a)*spd; vy = sin(a)*spd;
    maxLife = int(random(14, 48));
    life = maxLife;
    size = random(2.5, 5.5);
  }

  void update() {
    x += vx; y += vy;
    vx *= 0.94; vy *= 0.94;
    life--;
  }

  void display() {
    float a  = map(life, 0, maxLife, 0, 210);
    float sz = map(life, 0, maxLife, 0, size);
    noStroke();
    fill(red(c), green(c), blue(c), a * 0.28);
    rect(x, y, sz * 2.4, sz * 2.4);
    fill(red(c), green(c), blue(c), a);
    rect(x, y, sz, sz);
  }

  boolean isDead() { return life <= 0; }
}
