/*
U8glib graphical screen editor for 128x64 screens
 https://github.com/olikraus/u8glib
 
 mr-maurice@wanadoo.fr
 use keyboard to choose a tool
 */
final int zoom = 10;
final int gridX=128;
final int gridY=64;
final int leftMargin=5;
final int rightMargin=5;
final int topMargin=5;
final int bottomMargin=160;
ArrayList <Pixel> pxs;
ArrayList <GraphicElement> histo;
ArrayList <String> outputCode;
color black=color(0, 0, 0);
color blue=color(55, 133, 145);
Pixel[][] vpxs;//acces aux pixels par coordonnee absolue (O -> 127,0 -> 63);
Pixel fsp; //first selected pixel for 2D surface selections
DrawMode mode;
DrawMode lastUserMode;
Coordinate curMouse;
PImage thumbnail;
PImage backgroundImage;
static PImage itoolbt;
static PImage cicon;
boolean beginDraw2pt=false;
boolean endDraw2pt=false;
int lx1, ly1, lx2, ly2;//end points for lines
int lmx1, lmy1;
public enum DrawMode {
  LINE, 
    CIRCLE, 
    DISC, 
    BOX, 
    FRAME, 
    ERASE, 
    PARSE, 
    PIXEL;
}
void setup() {
  size(1290, 800);  // Size must be the first statement
  curMouse=new Coordinate(0, 0);
  lastUserMode=mode=DrawMode.PIXEL;
  vpxs=new Pixel[gridX][gridY]; //+1 ++ hack
  textFont(createFont("Calibri-30.vlw", 20));
  thumbnail=createImage(gridX, gridY, RGB);//miniature de l'ecran en cours de creation
  stroke(130);   // Set line drawing color to white
  frameRate(15);
  itoolbt=loadImage("toolbartip.png");
  pxs=new ArrayList<Pixel>();
  histo=new ArrayList<GraphicElement>();
  outputCode= new ArrayList<String>();
  int px=0;
  int py=0;
  Pixel p;
  for (int i=leftMargin; i<width-rightMargin; i=i+zoom) {
    for (int j=topMargin; j<height-bottomMargin; j=j+zoom) {
      p=new Pixel(i, j, px, py);
      pxs.add(p);
      vpxs[px][py]=p;
      py=py+1;
    }
    px=px+1;
    py=0;
  }
  cicon=itoolbt;
}
// The statements in draw() are executed until the 
// program is stopped. Each statement is executed in 
// sequence and after the last line is read, the first 
// line is executed again.
void draw() { 
  background(20);   // Clear the screen with a black background
  for (Pixel p : pxs) {
    p.display();
  }

  fill(200);
  if (backgroundImage != null) {
    tint(255, 126);
    image(backgroundImage, (gridX*zoom)/2-backgroundImage.width/2, (gridY*zoom)/2-backgroundImage.height/2);
  }
  tint(255, 255);
  text(mode+" MODE", 600, 700);
  text(curMouse.getX()+":"+curMouse.getY(), 600, 720);
  rect(1149, 669, 129, 65);
  image(cicon, 50, 680);
  image(thumbnail, 1150, 670);
}

void toolbarCycle() {
  if (key=='s') {
    mode=DrawMode.CIRCLE;
  } else if (key=='q') {
    mode=DrawMode.DISC;
  } else if (key=='d') {
    mode=DrawMode.BOX;
  } else if (key=='f') {
    mode=DrawMode.FRAME;
  } else if (key=='x') {
    mode=DrawMode.PIXEL;
  } else if (key=='c') {
    mode=DrawMode.LINE;
  } else if (key=='u') {
    loadBackgroundImage();
  } else if (key=='y') {
    clearBackgroundImage();
  }
  /*
  else if (key=='m') {
   histo.clear();
   outputCode.clear();
   clearAll();
   } */
  else if (key=='z') {
    undoLast();
  } else if (key=='p') {
    printCode();
  } else if (key=='o') {
    mode=DrawMode.PARSE;
  }

  lastUserMode=mode;
}

void undoLast() {
  try {
    histo.remove(histo.size()-1);//on retire le dernier element de l'historique
    outputCode.remove(outputCode.size()-1);
    clearAll();
    replay();
  } 
  catch (Exception e) {
    println("nothing to undo");
  }
} 
void replay() {
  for (GraphicElement g : histo) {
    mode=g.getType();
    if (mode==DrawMode.PIXEL) {
      g.setupPixel();
      drawPixel(true);
    } else if (mode==DrawMode.LINE) {
      g.setupRect();
      drawLine(true);
    } else if (mode==DrawMode.FRAME) {
      g.setupRect();
      drawFrame(true);
    } else if (mode==DrawMode.BOX) {
      g.setupRect();
      drawBox(true);
    } else if (mode==DrawMode.CIRCLE) {
      g.setupCircle();
      drawCircle(true);
    } else if (mode==DrawMode.DISC) {
    }
  }
  mode=lastUserMode;
}

void printCode() {
  println("/* u8glib instructions */");
  for (String e : outputCode) {
    println(e);
  }
}

void drawBox(boolean replay) {
  Corners k=new Corners(new Coordinate(lx1, ly1), new Coordinate(lx2, ly2));
  int top=k.top;
  int bottom=k.bottom;
  int left=k.left;
  int right=k.right;
  //println(": drawBox ", left, top, right, bottom);
  for (int i=left; i<=right; i++) {
    for (int j=bottom; j<=top; j++) {
      vpxs[i][j].setActive();
    }
  }

  if (!replay) {
    histo.add(new GraphicElement(mode, left, top, right, bottom));
  }
}

void drawFrame(boolean replay) {
  Corners k=new Corners(new Coordinate(lx1, ly1), new Coordinate(lx2, ly2));
  int top=k.top;
  int bottom=k.bottom;
  int left=k.left;
  int right=k.right;
  //draw top line
  for (int i=left; i<=right; i++) {
    vpxs[i][top].setActive();
  }
  //draw bottom line
  for (int i=left; i<=right; i++) {
    vpxs[i][bottom].setActive();
  }
  //draw left line
  for (int j=bottom; j<=top; j++) {
    vpxs[left][j].setActive();
  }
  //draw right line
  for (int j=bottom; j<=top; j++) {
    vpxs[right][j].setActive();
  }
  if (!replay) {
    // histo.add(new GraphicElement(mode, lx1, ly1, right-left+1, top-bottom+1));
    histo.add(new GraphicElement(mode, left, top, right, bottom));
  }
}

void drawLine(boolean replay) {
  ArrayList<Coordinate> coordinatesArray = new ArrayList<Coordinate>();
  if (!replay) {
    histo.add(new GraphicElement(mode, lx1, ly1, lx2, ly2));
  }
  // Define differences and error check
  int dx = Math.abs(lx2 - lx1);
  int dy = Math.abs(ly2 - ly1);
  int sx = (lx1 < lx2) ? 1 : -1;
  int sy = (ly1 < ly2) ? 1 : -1;
  int err = dx - dy;
  // Set first coordinates
  coordinatesArray.add(new Coordinate(lx1, ly1));
  // Main loop
  while (!((lx1 == lx2) && (ly1 == ly2))) {
    int e2 = err << 1;
    if (e2 > -dy) {
      err -= dy;
      lx1 += sx;
    }
    if (e2 < dx) {
      err += dx;
      ly1 += sy;
    }
    coordinatesArray.add(new Coordinate(lx1, ly1));
  }

  for (Coordinate c : coordinatesArray) {
    vpxs[c.x1][c.y1].setActive();
  }
}

public void drawCircle (boolean replay) {
  int x, y, m ;
  int x1=lx1;
  int y1=ly1;
  //int radius=Math.abs(lx1-lx2);
  int radius=distance();
  if (!replay) {
    histo.add(new GraphicElement(mode, lx1, ly1, radius));
  }
  x = 0 ;
  y = radius ;             // on se place en haut du cercle 
  m = 5 - 4*radius ;       // initialisation
  while ( x <= y ) {        // tant qu'on est dans le second octant
    lx1=x+x1;
    ly1=y+y1;
    drawPixel(true);
    lx1=y+x1;
    ly1=x+y1;
    drawPixel(true) ;
    lx1=-x+x1;
    ly1=y+y1;
    drawPixel(true) ;
    lx1=-y+x1;
    ly1=x+y1;
    drawPixel(true) ;
    lx1=x+x1;
    ly1=-y+y1;
    drawPixel(true) ;
    lx1=y+x1;
    ly1=-x+y1;
    drawPixel(true) ;
    lx1=-x+x1;
    ly1=-y+y1;
    drawPixel(true) ;
    lx1=-y+x1;
    ly1=-x+y1;
    drawPixel(true) ;
    if ( m > 0) {       //choix du point F
      y = y - 1 ;
      m = m - 8*y ;
    }
    x = x + 1 ;
    m = m + 8*x + 4 ;
  }
}

void drawPixel(boolean replay) {
  if (!replay) {
    vpxs[curMouse.getX()][curMouse.getY()].setActive();
    lx1=curMouse.getX();
    ly1=curMouse.getY();
    histo.add(new GraphicElement(mode, lx1, ly1));
  }
  //MODE REPLAY
  if (replay) {
    for (Pixel p : pxs) {
      if (p.isAt(lx1, ly1)) {
        p.setActive();
      }
    }
  }
}

void clearAll() {
  for (Pixel p : pxs) {
    p.setInactive();
  }
}

void keyReleased() {
  toolbarCycle();
}

void mouseMoved() {
  curMouse=getAbsolute(mouseX, mouseY);
  //deselectionne ligne horizontale au dessus de la souris
  Pixel p;
  for (int i=0; i<gridX; i++) {
    for (int j=0; j<curMouse.getY(); j++) {
      p=vpxs[i][j];
      if (!p.getActive()) {
        p.setUnselected();
      }
    }
  }
  //deselectionne ligne horizontale en dessous de la souris
  for (int i=0; i<gridX; i++) {
    for (int j=curMouse.getY(); j<gridY; j++) {
      p=vpxs[i][j];
      if (!p.getActive()) {
        p.setUnselected();
      }
    }
  }
  //dessine une barre horizontale au y de la souris
  for (int i=0; i<gridX; i++) {
    p=vpxs[i][curMouse.getY()];
    if (!p.getActive()) {
      p.setSelected();
    }
  }
  //dessine une barre verticale au x de la souris
  for (int i=0; i<gridY; i++) {
    p=vpxs[curMouse.getX()][i];
    if (!p.getActive()) {
      p.setSelected();
    }
  }
}

void mouseReleased() {
  Pixel p;
  getAbsolute(mouseX, mouseY);
  if (mode==DrawMode.PIXEL) {
    drawPixel(false);
  } else if (mode==DrawMode.LINE||mode==DrawMode.DISC||mode==DrawMode.CIRCLE||mode==DrawMode.FRAME||mode==DrawMode.BOX||mode==DrawMode.PARSE) {
    if (!beginDraw2pt && !endDraw2pt) {
      beginDraw2pt=true;
      p=vpxs[curMouse.getX()][curMouse.getY()];
      fsp=p;
      p.setEndPoint();
      lx1=p.getX();
      ly1=p.getY();
    } else if (beginDraw2pt && !endDraw2pt) {
      endDraw2pt=true;
      p=vpxs[curMouse.getX()][curMouse.getY()];
      lx2=p.getX();
      ly2=p.getY();
      fsp.unsetEndPoint();
      beginDraw2pt=false;
      endDraw2pt=false;
      if (mode==DrawMode.LINE) {
        drawLine(false);
      } else if (mode==DrawMode.FRAME) {
        drawFrame(false);
      } else if (mode==DrawMode.BOX) {
        drawBox(false);
      } else if (mode==DrawMode.CIRCLE) {
        drawCircle(false);
      } else if (mode==DrawMode.DISC) {
        //nothing lol
      } else if (mode==DrawMode.PARSE) {
        parseZone();
      }
    }
  }
}


class Pixel {
  color activeColor=200;
  color inactiveColor=20;
  color hoverColor=#006699 ;
  color c=inactiveColor;
  color endPointColor=#C8CB2B;
  boolean active=false;
  boolean endPoint=false;
  int x;//visual x value
  int y;//visual y value
  int tx;//actual target value
  int ty;//actual target value
  Pixel(int px, int py, int ptx, int pty) {
    x=px;
    y=py;
    tx=ptx;
    ty=pty;
  }

  public String getStringStatus() {
    String r="0";
    if (active==true) {
      r="1";
    } else {
      r="0";
    }
    return r;
  }
  /*
returns true if pixel currently active
   */
  public boolean getActive() {
    return (active||endPoint);
  }

  public void setEndPoint() {
    endPoint=true;
    c=endPointColor;
  }
  public void unsetEndPoint() {
    endPoint=false;
    c=endPointColor;
  }

  public int getX() {
    return tx;
  }
  public int getY() {
    return ty;
  }

  public void printCoord() {
    println("x: "+tx+ " y: "+ty);
  }
  void isHovered(int mx, int my) {
    if (isOver(mx, my) && c==inactiveColor) {
      c=hoverColor;
    } else {
      c=inactiveColor;
    }
  }

  boolean isOver(int mx, int my) {
    boolean r=false;
    if (mx >= x 
      && mx <= x+zoom
      && my > y
      && my < y+zoom) {
      r=true;
    }
    return r;
  }

  //returns true if present at mousex,mousey
  public boolean isPressed(int mx, int my) {
    boolean r=false;
    if (isOver(mx, my)) {
      r=true;
    }
    return r;
  }

  public void setSelected() {
    c=hoverColor;
  }

  public void setUnselected() {
    c=inactiveColor;
  }

  //returns true if present at x1,y1 canonical
  public boolean isAt(int x1, int y1) {
    boolean r=false;
    if (tx==x1 && ty == y1) {
      //this.setActive();
      r=true;
    }
    return r;
  }

  void display() {
    fill(c);
    rect(x, y, zoom, zoom);
  }

  public void setActive() {
    c=activeColor;
    active=true;
    updateImagePreview(tx, ty, false);
  }

  public void setInactive() {
    c=inactiveColor;
    active=false;
    updateImagePreview(tx, ty, true);
  }
}

/**prints a u8glib drawBitmap instruction corresponding to a graphic area selected by the user**/
public String[] parseZone() {
  Corners c=new Corners(new Coordinate(lx1, ly1), new Coordinate(lx2, ly2));
  //rounds selection length to nearest higher multiple of 8
  int length8mul=0;//selection width in multiples of 8 (17px wide=>3)
  if (c.cwidth>0) {
    if ((c.cwidth%8)>0) {
      length8mul=(c.cwidth/8)+1;
    } else if ((c.cwidth%8)==0) {
      length8mul=(c.cwidth/8);
    }
  } else {
    length8mul=1;
  }  
  int bHeight=c.cheight+1;
  int arraySize=length8mul*bHeight;
  String[] r=new String[arraySize];
  int ind=0;
  println("const uint8_t bitmap[] U8G_PROGMEM ={");
  for (int j=c.bottom; j<(c.bottom+bHeight); j++) {
    for ( int i=c.left; i<(length8mul*8+c.left); i=i+8) {
      //reading byte at (i,j);
      r[ind]="0x"+hex((byte)Integer.parseInt(buildByte(i, j), 2));
    }
    print(r[ind]);
    println(",");
  }
  println("};");


  println("u8g_drawBitmapP(&u8g,", c.left, ",", c.bottom, ",", length8mul, ",", bHeight+",bitmap);");
  return r;
}

public String buildByte(int i, int j) {
  String r="";
  r+=vpxs[i][j].getStringStatus();
  r+=vpxs[i+1][j].getStringStatus();
  r+=vpxs[i+2][j].getStringStatus();
  r+=vpxs[i+3][j].getStringStatus();
  r+=vpxs[i+4][j].getStringStatus();
  r+=vpxs[i+5][j].getStringStatus();
  r+=vpxs[i+6][j].getStringStatus();
  r+=vpxs[i+7][j].getStringStatus();
  return r;
}

public void updateImagePreview(int tx, int ty, boolean clear) {

  try {
    if (clear) {
      thumbnail.pixels[tx+ty*gridX]=black;
    } else {
      thumbnail.pixels[tx+ty*gridX]=blue;
    }
  } 
  catch (ArrayIndexOutOfBoundsException e) {
    //ignoring dis
  }
  thumbnail.updatePixels();
}

/*element graphique pour historisation*/
class GraphicElement {
  DrawMode type;
  int gwidth=0, gheight=0;
  int radius=0;//for circles 
  int x1=0, y1=0, x2=0, y2=0;
  String u8code="";
  final int num=histo.size();
  //for single pixels
  public GraphicElement(DrawMode mode, int x, int y) {
    this.type=mode;
    // this.x=x;
    // this.y=y;
    this.x1=x;
    this.y1=y;
    u8code="u8g_DrawPixel(&u8g"+ ","+x1+ ","+y1+");";
    outputCode.add(u8code);
  }
  //for boxes,frames,lines
  //(x1,y1) (x2,y2) begin:end points
  public GraphicElement(DrawMode mode, int x1, int y1, int x2, int y2) {
    int outHeight=0;//devrait pas etre necessaire
    int outWidth=0;
    this.type=mode;
    if (mode==DrawMode.FRAME||mode==DrawMode.BOX) {
      this.gwidth=Math.abs(x2-x1);
      this.gheight=Math.abs(y2-y1);
      this.x1=x1;
      this.y1=y1;
      this.x2=x2;
      this.y2=y2;
      outWidth=gwidth+1;
      outHeight=gheight+1;
      if (mode==DrawMode.BOX) {
        u8code="u8g_DrawBox(&u8g"+ ","+Math.min(x1, x2)+ ","+Math.min(y1, y2)+ ","+outWidth+","+outHeight+");";//+1 gros hack
        //println(u8code);
      } else if (mode==DrawMode.FRAME) {
        u8code="u8g_DrawFrame(&u8g"+ ","+Math.min(x1, x2)+ ","+Math.min(y1, y2)+ ","+outWidth+","+outHeight+");";//+1 gros  hack
        //println(u8code);
      }
    } else if (mode==DrawMode.LINE) {
      this.x1=x1;
      this.y1=y1;
      this.x2=x2;
      this.y2=y2;
      u8code="u8g_DrawLine(&u8g"+ ","+x1+ ","+y1+ ","+x2+ ","+y2+");";
      //println(u8code);
    }
    outputCode.add(u8code);
  }
  //for circles
  public GraphicElement(DrawMode mode, int x, int y, int radius) {
    this.type=mode;
    this.x1=x;
    this.y1=y;
    this.radius=radius;
    u8code="u8g_DrawCircle(&u8g"+ ","+x1+ ","+y1+ ","+radius+ ",U8G_DRAW_ALL);";
    //println(u8code);
    outputCode.add(u8code);
  }
  public void setupPixel() {
    lx1=this.x1;
    ly1=this.y1;
  }

  public void setupCircle() {
    lx1=this.x1;
    ly1=this.y1;
    lx2=this.x1+this.radius;//methode radius calcule juste sur la ligne horizontale
    ly2=this.y1;
  }

  public void setupRect() {
    lx1=this.x1;
    ly1=this.y1;
    lx2=this.x2;
    ly2=this.y2;
  }
  public DrawMode getType() {
    return this.type;
  }
}

int distance() {
  return round(dist(lx1, ly1, lx2, ly2));
}

Coordinate getAbsolute(int mx, int my) {
  int cx, cy;
  cx=floor((mx-leftMargin)/zoom);
  cy=floor((my-topMargin)/zoom);
  if (cy>=gridY) {
    cy=gridY-1;
  }
  if (cx>=gridX) {
    cx=gridX-1;
  }
  curMouse.setX(cx);
  curMouse.setY(cy);
  return curMouse;
}

class Coordinate {
  int x1, y1;
  public Coordinate(int x, int y) {
    x1=x;
    y1=y;
  }
  public int getX() {
    return x1;
  }
  public int getY() {
    return y1;
  }

  public void setX(int x) {
    this.x1=x;
  }

  public void setY(int y) {
    this.y1=y;
  }
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("Background image " + selection.getAbsolutePath());
    backgroundImage=loadImage(selection.getAbsolutePath());
  }
}

public void clearBackgroundImage() {
  backgroundImage=null;
}

public void loadBackgroundImage() {
  selectInput("Select a file to process:", "fileSelected");
}

static class Corners {
  Coordinate a;
  Coordinate b;
  public  int left, right, top, bottom;
  public int cwidth, cheight;
  public Corners(Coordinate c1, Coordinate c2) {
    a=c1;
    b=c2;
    left=min(a.getX(), b.getX());
    right=max(a.getX(), b.getX());
    top=max(a.getY(), b.getY());
    bottom=min(a.getY(), b.getY());
    cheight=top-bottom;
    cwidth=right-left;
  }
}