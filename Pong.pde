import javax.sound.sampled.*;

int TELA_MENU = 0;
int TELA_JOGO = 1;
int TELA_GAMEOVER = 2;
int estadoAtual = TELA_MENU;

float bolaX, bolaY;
float bolaVelX, bolaVelY;
float bolaDiametro = 16;
float velocidadeInicial = 5;

float raqueteLargura = 15;
float raqueteAltura = 80;
float jogador1X, jogador1Y;
float jogador2X, jogador2Y;
float velocidadeRaquete = 7;

boolean wPressionado, sPressionado;
boolean upPressionado, downPressionado;

int pontosJogador1 = 0;
int pontosJogador2 = 0;
int pontuacaoMaxima = 5;

int globalFreq;
int globalDur;

void setup() {
  size(800, 600);
  frameRate(60);
  noStroke();
  resetarJogo();
}

void draw() {
  background(0);
  
  if (estadoAtual == TELA_MENU) {
    desenharMenu();
  } else if (estadoAtual == TELA_JOGO) {
    atualizarJogo();
    desenharJogo();
  } else if (estadoAtual == TELA_GAMEOVER) {
    desenharGameOver();
  }
}

void keyPressed() {
  if (key == 'w' || key == 'W') wPressionado = true;
  if (key == 's' || key == 'S') sPressionado = true;
  
  if (keyCode == UP) upPressionado = true;
  if (keyCode == DOWN) downPressionado = true;
  
  if (estadoAtual == TELA_MENU && key == ' ') {
    estadoAtual = TELA_JOGO;
  }
  if (estadoAtual == TELA_GAMEOVER && key == ' ') {
    pontosJogador1 = 0;
    pontosJogador2 = 0;
    resetarJogo();
    estadoAtual = TELA_JOGO;
  }
}

void keyReleased() {
  if (key == 'w' || key == 'W') wPressionado = false;
  if (key == 's' || key == 'S') sPressionado = false;
  if (keyCode == UP) upPressionado = false;
  if (keyCode == DOWN) downPressionado = false;
}

void atualizarJogo() {
  if (wPressionado && jogador1Y > 0) {
    jogador1Y -= velocidadeRaquete;
  }
  if (sPressionado && jogador1Y < height - raqueteAltura) {
    jogador1Y += velocidadeRaquete;
  }
  
  if (upPressionado && jogador2Y > 0) {
    jogador2Y -= velocidadeRaquete;
  }
  if (downPressionado && jogador2Y < height - raqueteAltura) {
    jogador2Y += velocidadeRaquete;
  }
  
  bolaX += bolaVelX;
  bolaY += bolaVelY;
  
  if (bolaY - (bolaDiametro/2) <= 0 || bolaY + (bolaDiametro/2) >= height) {
    bolaVelY *= -1;
    reproduzirSom(440, 0.08);
  }
  
  if (bolaX - (bolaDiametro/2) <= jogador1X + raqueteLargura && bolaX + (bolaDiametro/2) >= jogador1X) {
    if (bolaY >= jogador1Y && bolaY <= jogador1Y + raqueteAltura) {
      bolaVelX *= -1;
      bolaX = jogador1X + raqueteLargura + (bolaDiametro/2);
      reproduzirSom(880, 0.05);
    }
  }
  
  if (bolaX + (bolaDiametro/2) >= jogador2X && bolaX - (bolaDiametro/2) <= jogador2X + raqueteLargura) {
    if (bolaY >= jogador2Y && bolaY <= jogador2Y + raqueteAltura) {
      bolaVelX *= -1;
      bolaX = jogador2X - (bolaDiametro/2);
      reproduzirSom(880, 0.05);
    }
  }
  
  if (bolaX < 0) {
    pontosJogador2++;
    reproduzirSom(150, 0.35);
    verificarFimDeJogo();
  } else if (bolaX > width) {
    pontosJogador1++;
    reproduzirSom(150, 0.35);
    verificarFimDeJogo();
  }
}

void resetarJogo() {
  jogador1X = 30;
  jogador1Y = (height / 2) - (raqueteAltura / 2);
  jogador2X = width - 30 - raqueteLargura;
  jogador2Y = (height / 2) - (raqueteAltura / 2);
  
  bolaX = width / 2;
  bolaY = height / 2;
  
  bolaVelX = (random(1) > 0.5 ? 1 : -1) * velocidadeInicial;
  bolaVelY = (random(1) > 0.5 ? 1 : -1) * random(2, 4);
}

void verificarFimDeJogo() {
  if (pontosJogador1 >= pontuacaoMaxima || pontosJogador2 >= pontuacaoMaxima) {
    estadoAtual = TELA_GAMEOVER;
  } else {
    resetarJogo();
  }
}

void desenharMenu() {
  textAlign(CENTER, CENTER);
  textSize(48);
  fill(255);
  text("PONG", width / 2, height / 2 - 50);
  textSize(20);
  text("Pressione ESPAÇO para Iniciar", width / 2, height / 2 + 50);
}

void desenharJogo() {
  fill(255, 100);
  for (int i = 0; i < height; i += 30) {
    rect(width / 2 - 2, i, 4, 15);
  }
  
  fill(255);
  rect(jogador1X, jogador1Y, raqueteLargura, raqueteAltura);
  rect(jogador2X, jogador2Y, raqueteLargura, raqueteAltura);
  ellipse(bolaX, bolaY, bolaDiametro, bolaDiametro);
  
  textSize(36);
  text(pontosJogador1, width / 2 - 100, 50);
  text(pontosJogador2, width / 2 + 100, 50);
}

void desenharGameOver() {
  textAlign(CENTER, CENTER);
  textSize(48);
  fill(255);
  if (pontosJogador1 >= pontuacaoMaxima) {
    text("JOGADOR 1 VENCEU!", width / 2, height / 2 - 50);
  } else {
    text("JOGADOR 2 VENCEU!", width / 2, height / 2 - 50);
  }
  textSize(20);
  text("Pressione ESPAÇO para Reiniciar", width / 2, height / 2 + 50);
}

void reproduzirSom(float frequencia, float duracaoSegundos) {
  globalFreq = (int)frequencia;
  globalDur = (int)(duracaoSegundos * 1000);
  thread("executarSomWindows");
}

void executarSomWindows() {
  try {
    String comando = "powershell -Command [console]::beep(" + globalFreq + "," + globalDur + ")";
    Runtime.getRuntime().exec(comando);
  } catch (Exception e) {
    // Falha silenciosa
  }
}