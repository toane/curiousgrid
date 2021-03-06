/* //<>//
U8glib graphical screen editor
 edit gridX and gridY for target screen size
 https://github.com/olikraus/u8glib
 use keyboard to choose a tool
 
 mr-maurice@wanadoo.fr
 */
import javax.swing.*;
import java.awt.Color;
import java.awt.BorderLayout;
import java.awt.event.*;
import java.awt.datatransfer.*;
import java.awt.Toolkit;

///Main configuration variables
final int gridX=128;//number of horizontal pixels to edit
final int gridY=64;//number of vertical pixels to edit
//

final int cellSize = 10;//displayed dimension for each (square) pixel

final int leftMargin=5;
final int rightMargin=5;
final int topMargin=5;
final int bottomMargin=160;
ArrayList <Pixel> pxs;
ArrayList <GraphicElement> histo;
GraphicElement lastGraphicElement=null;//last drawn (used to historize bitmap drawings) 
//ArrayList <String> outputCode;
ArrayList <Integer> rlePicture;
color black=color(0, 0, 0);
color blue=color(55, 133, 145);
Pixel[][] vpxs;//acces aux pixels par coordonnee absolue (O -> 127,0 -> 63);
Pixel fsp; //first selected pixel for 2D surface selections
DrawMode mode;
DrawMode lastUserMode;
Coordinate curMouse;
PImage thumbnail;
PImage backgroundImage=null, bitmapFile=null;
static PImage itoolbt;
static PImage cicon;
boolean beginDraw2pt=false;
boolean endDraw2pt=false;
int lx1, ly1, lx2, ly2;//end points for lines
int lmx1, lmy1;
JFrame codeFrame;
JTextArea codeArea;

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
  codeFrame=new JFrame("C code");
  codeFrame.setSize(1000, 500);
  codeArea=new JTextArea();
  codeArea.setLineWrap(true);
  codeArea.setBackground(new Color(20, 20, 20));
  codeArea.setForeground(new Color(200, 200, 200));
  codeArea.setEditable(false);
  JScrollPane scrollPane = new JScrollPane(codeArea);
  codeFrame.add(scrollPane);
  //codeFrame.getContentPane().add(scrollPane,BorderLayout.NORTH);
  JButton copyButton=new JButton("copy to clipboard");
  copyButton.addActionListener(new ButtonListener());
  codeFrame.add(copyButton, BorderLayout.SOUTH);
  codeFrame.setVisible(true); 
  
  curMouse=new Coordinate(0, 0);
  lastUserMode=mode=DrawMode.PIXEL;
  vpxs=new Pixel[gridX][gridY];
  textFont(createFont("Cabin-Regular.ttf", 20));
  thumbnail=createImage(gridX, gridY, RGB);//miniature preview
  stroke(130);  
  frameRate(15);
  itoolbt=loadImage("toolbar.png");
  pxs=new ArrayList<Pixel>();
  histo=new ArrayList<GraphicElement>();
  //outputCode= new ArrayList<String>();
  int px=0;
  int py=0;
  Pixel p;
  for (int i=leftMargin; i<cellSize*gridX; i=i+cellSize) {
    for (int j=topMargin; j<cellSize*gridY; j=j+cellSize) {
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

    float bidx, bidy;//background display dimensions
    float reduce=1;//resize ratio
    bidx=backgroundImage.width;
    bidy=backgroundImage.height;

    if (backgroundImage.width>(gridX*cellSize)) {
      reduce=(float)backgroundImage.width/(gridX*cellSize);
      bidx=backgroundImage.width/reduce;
      bidy=backgroundImage.height/reduce;
    }

    if (backgroundImage.height>(gridY*cellSize)) {

      reduce=(float)backgroundImage.height/(gridY*cellSize);
      bidx=backgroundImage.width/reduce;
      bidy=backgroundImage.height/reduce;
    }

    // println(gridX*cellSize, gridY*cellSize);
    // println("[", backgroundImage.width, backgroundImage.height, "] -> ", bidx, bidy);
    image(backgroundImage, (gridX*cellSize)/2-bidx/2, (gridY*cellSize)/2-bidy/2, bidx, bidy);
  }
  tint(255, 255);
  text(mode+" MODE", 600, 700);
  text(curMouse.getX()+":"+curMouse.getY(), 600, 720);
  image(cicon, 5, 668);
  rect(width-gridX-2-rightMargin, 669, gridX+1, gridY+1);
  //display preview thumbnail
  image(thumbnail, width-gridX-1-rightMargin, 670);
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
    //clearBackgroundImage();
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
  } else if (key=='t') {
    loadBitmap();
  }

  lastUserMode=mode;
}

void undoLast() {
  try {
    GraphicElement ge=histo.get(histo.size()-1);//recuperer dernier element
    if (ge.getPrevious()!=null) {//if last element is part of a bitmap
      while (ge.getPrevious()!=null) {//verifier s'il possede un prev
        println("del ", ge, " linked to ", ge.getPrevious());
        //retirer l'element de l'historique
        ge=ge.getPrevious();
        histo.remove(histo.size()-1);
      }
      histo.remove(histo.size()-1);//on retire le dernier element (dont ge.getprevious()==null
      println("del ", ge, " linked to ", ge.getPrevious());
      lastGraphicElement=null;
    } else {
      histo.remove(histo.size()-1);//on retire le dernier element de l'historique
      // outputCode.remove(outputCode.size()-1);
    }
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
      drawPixel(true, false);
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
  /*
  for (String e : outputCode) {
   println(e);
   }
   */
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
    drawPixel(true, false);
    lx1=y+x1;
    ly1=x+y1;
    drawPixel(true, false) ;
    lx1=-x+x1;
    ly1=y+y1;
    drawPixel(true, false) ;
    lx1=-y+x1;
    ly1=x+y1;
    drawPixel(true, false) ;
    lx1=x+x1;
    ly1=-y+y1;
    drawPixel(true, false) ;
    lx1=y+x1;
    ly1=-x+y1;
    drawPixel(true, false) ;
    lx1=-x+x1;
    ly1=-y+y1;
    drawPixel(true, false) ;
    lx1=-y+x1;
    ly1=-x+y1;
    drawPixel(true, false) ;
    if ( m > 0) {       //choix du point F
      y = y - 1 ;
      m = m - 8*y ;
    }
    x = x + 1 ;
    m = m + 8*x + 4 ;
  }
}

void drawPixel(boolean replay, boolean bitmap) {
  if (!replay) {
    if (!bitmap) {
      vpxs[curMouse.getX()][curMouse.getY()].setActive();
      lx1=curMouse.getX();
      ly1=curMouse.getY();
      histo.add(new GraphicElement(mode, lx1, ly1));
    } else {
      vpxs[lx1][ly1].setActive();
      GraphicElement ge=new GraphicElement(mode, lx1, ly1, lastGraphicElement);
      histo.add(ge);
      lastGraphicElement=ge;
    }
    //histo.add(new GraphicElement(mode, lx1, ly1));
  }
  //MODE REPLAY
  else {
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
  //getAbsolute(mouseX, mouseY);
  if (mode==DrawMode.PIXEL) {
    drawPixel(false, false);
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
      && mx <= x+cellSize
      && my > y
      && my < y+cellSize) {
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
    rect(x, y, cellSize, cellSize);
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


  println("u8g_DrawBitmapP(&u8g,", c.left, ",", c.bottom, ",", length8mul, ",", bHeight+",bitmap);");
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
  GraphicElement prev=null;//for pixels linked together in a bitmap
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
    u8code="u8g_DrawPixel(&u8g"+ ","+x1+ ","+y1+");\n";
    codeArea.append(u8code);
    //outputCode.add(u8code);
  }
  //for single pixels part of a bitmap
  public GraphicElement(DrawMode mode, int x, int y, GraphicElement prev) {
    this.prev=prev;
    this.type=mode;    
    this.x1=x;
    this.y1=y;
    u8code="u8g_DrawPixel(&u8g"+ ","+x1+ ","+y1+");\n";
    //codeArea.append(u8code);
    //outputCode.add(u8code);
    println("add ", this, " linked to ", prev);
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
        u8code="u8g_DrawBox(&u8g"+ ","+Math.min(x1, x2)+ ","+Math.min(y1, y2)+ ","+outWidth+","+outHeight+");\n";//+1 gros hack
        //println(u8code);
      } else if (mode==DrawMode.FRAME) {
        u8code="u8g_DrawFrame(&u8g"+ ","+Math.min(x1, x2)+ ","+Math.min(y1, y2)+ ","+outWidth+","+outHeight+");\n";//+1 gros  hack
        //println(u8code);
      }
    } else if (mode==DrawMode.LINE) {
      this.x1=x1;
      this.y1=y1;
      this.x2=x2;
      this.y2=y2;
      u8code="u8g_DrawLine(&u8g"+ ","+x1+ ","+y1+ ","+x2+ ","+y2+");\n";
      //println(u8code);
    }
    //outputCode.add(u8code);
    codeArea.append(u8code);
  }
  //for circles
  public GraphicElement(DrawMode mode, int x, int y, int radius) {
    this.type=mode;
    this.x1=x;
    this.y1=y;
    this.radius=radius;
    u8code="u8g_DrawCircle(&u8g"+ ","+x1+ ","+y1+ ","+radius+ ",U8G_DRAW_ALL);\n";
    //println(u8code);
    //outputCode.add(u8code);
    codeArea.append(u8code);
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
  //returns last linked GraphicElement if any
  public GraphicElement getPrevious() {
    return prev;
  }
}

int distance() {
  return round(dist(lx1, ly1, lx2, ly2));
}

Coordinate getAbsolute(int mx, int my) {
  int cx, cy;
  cx=floor((mx-leftMargin)/cellSize);
  cy=floor((my-topMargin)/cellSize);
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

void backgroundImageSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("//Background image " + selection.getAbsolutePath());
    backgroundImage=loadImage(selection.getAbsolutePath());
  }
}

void bitmapSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("//Bitmap file " + selection.getAbsolutePath());
    bitmapFile=loadImage(selection.getAbsolutePath());
    //si l'image ouverte n'est pas aux dimensions de la grille
    if (bitmapFile.width != gridX || bitmapFile.height != gridY) {
      JOptionPane.showMessageDialog(frame, "Picture file should be "+gridX+" by "+gridY+"px");
    } else {    
      readBitmap();
      //codeFrame.setVisible(true);
    }
  }
}


public void clearBackgroundImage() {
  backgroundImage=null;
}

public void loadBackgroundImage() {
  if (backgroundImage==null) {
    selectInput("Select existing bitmap", "backgroundImageSelected");
  } else if (backgroundImage!=null) {
    backgroundImage=null;
    //clearAll();
    //histo.clear();
  }
}

public void loadBitmap() {
  if (bitmapFile==null) {
    selectInput("Select existing bitmap", "bitmapSelected");
  } else if (bitmapFile!=null) {
    bitmapFile=null;
    //clearAll();
    //histo.clear();
    codeArea.setText("");
    //codeFrame.setVisible(false);
  }
}


public Corners getBoundaries(PImage im) {
  color c;
  int x1=gridX, y1=gridY;//coordinates for top left corner
  int x2=0, y2=0;//coordinates for bottom right corner
  for (int i=0; i<im.height; i++) {
    for (int j=0; j<im.width; j++) {
      c=im.get(j, i) <<8 ;//masking alpha value, all non black pixels are considered "on"
      if ( c !=0 ) {
        if (j<x1) {
          x1=j;
        }
        if (i<y1) {
          y1=i;
        }

        if (j>x2) {
          x2=j;
        }
        if (i>y2) {
          y2=i;
        }
      }
    }
  }
  return new Corners(new Coordinate(x1, y1), new Coordinate(x2, y2));
}

/*
*readfile: true if reading file, false if clearing screen
 */
public void readBitmap() {
  color c;
  ArrayList <Boolean> btmp=new ArrayList();
  Corners cdn=getBoundaries(bitmapFile);
  //println("topleft at", cdn.left, cdn.bottom);
  //println("bottom right at", cdn.right, cdn.top); 
  //int x=cdn.left, y=cdn.top;//coordinates of the first on pixel we find
  for (int i=cdn.bottom; i<cdn.bottom+cdn.cheight+1; i++) {
    for (int j=cdn.left; j<cdn.left+cdn.cwidth+1; j++) {
      c=(bitmapFile.get(j, i) << 8);//masking alpha value, all non black pixels are considered "on"
      if ( c !=0 ) {
        lx1=j;
        ly1=i;
        drawPixel(false, true);
        btmp.add(true);
      } else {
        btmp.add(false);
      }
    }
  }
  lastGraphicElement=null;
  rleEncoding(btmp, cdn);
}

/*
generates 8 bit RLE compressed C code for the image p, off pixels first
 p: binary image (todo: keep length);
 x,y: coordinates of the first on pixel for the image
 */
public void rleEncoding(ArrayList<Boolean> p, Corners cdn) {
  int fx=cdn.left;
  int fy=cdn.bottom;
  ArrayList<Integer> pxc=new ArrayList();
  int black=0;
  int white=0;
  Boolean lastseen=true;//current color of the pixels we're counting, starting w black (false)
  for (Boolean b : p) {
    if (lastseen != b) {
      if (!b) {
        //println(":", white);
        if (white>255) {
          for (int i=1; i<white/255+1; i++) {

            pxc.add(255);
            pxc.add(0);
          }
          if (white%255>0) {

            pxc.add(white%255);
          }
        } else { 

          pxc.add(white);
        }
      }
      if (b) {

        if (black>255) {          
          for (int i=1; i<black/255+1; i++) {

            pxc.add(255);
            pxc.add(0);
          }
          if (black%255>0) {

            pxc.add(black%255);
          }
        } else {

          pxc.add(black);
        }
      }
    }
    if (!b) {//counting off pixels
      white=0;
      black++;
      //print("_");
    } else if (b) {//counting on pixels
      black=0;
      white++;
      //print("1");
    }

    lastseen=b;
  }
  //dealing with the last element
  if (white>0) {
    //println(":", white);
    if (white>255) {
      for (int i=1; i<white/255+1; i++) {

        pxc.add(255);
        pxc.add(0);
      }
      if (white%255>0) {

        pxc.add(white%255);
      }
    } else {

      pxc.add(white);
    }
  }
  if (black>0) {
    //println(":", black);
    if (black>255) {

      for (int i=1; i<black/255+1; i++) {

        pxc.add(255);
        pxc.add(0);
      }
      if (black%255>0) {

        pxc.add(black%255);
      }
    } else {

      pxc.add(black);
    }
  }
  //builds C array code 
  //println("#define IMG_LENGTH "+(cdn.cwidth+1));
  codeArea.append("#define IMG_LENGTH "+(cdn.cwidth+1)+"\n");
  //println("#define RLE_BYTES ", pxc.size());
  codeArea.append("#define RLE_BYTES "+ pxc.size()+"\n");
  //println ("uint8_t img1[RLE_BYTES] = {");
  codeArea.append("uint8_t img1[RLE_BYTES] = {");
  for (int i=0; i<pxc.size()-1; i++) {
    //print("0x"+hex(pxc.get(i), 2), ", ");    
    codeArea.append("0x"+hex(pxc.get(i), 2)+ ", ");
    //  print("d"+pxc.get(i));
  } 
  codeArea.append("0x"+hex(pxc.get(pxc.size()-1), 2));//the last element doesn't need a ','
  //print("0x"+hex(pxc.get(pxc.size()-1), 2));//the last element doesn't need a ','
  codeArea.append("};"+"\n");
  //print("};");


  //draw method
  /*
  println("");
   println("void draw(void){");
   println ("\tuint8_t fx=", fx, ";");
   println ("\tuint8_t fy=", fy, ";");
   println("\tuint8_t x=fx,y=fy;\r\n\tuint8_t c=0x01;//color code for the first color in the RLE (0x00: black, 0x01:white)\r\n\tuint16_t i;\r\n\tuint8_t j;\r\n\tfor( i = 0; i < RLE_BYTES; i++ ) {//read image byte array\r\n\t\tfor (j=0;j<img1[i];j++){//write current byte to screen\r\n\r\n\t\t\tif (c==0x01){\r\n\t\t\t\tu8g_DrawPixel(&u8g,x,y);\r\n\t\t\t}\r\n\t\t\tif(x<fx+IMG_LENGTH-1){\r\n\t\t\t\tx++;\r\n\t\t\t}else{\r\n\t\t\t\tx=fx;\r\n\t\t\t\ty=y+1;\r\n\t\t\t}\r\n\t\t}\r\n\t\tc=c^0x01;//toggle color\r\n\t}");
   println ("\r\n}");
   
   println("");
   */
  codeArea.append("void draw(void){"+"\n");
  codeArea.append ("\tuint8_t fx="+fx+ ";"+"\n");
  codeArea.append ("\tuint8_t fy="+ fy+";"+"\n");
  codeArea.append("\tuint8_t x=fx,y=fy;\r\n\tuint8_t c=0x01;//color code for the first color in the RLE (0x00: black, 0x01:white)\r\n\tuint16_t i;\r\n\tuint8_t j;\r\n\tfor( i = 0; i < RLE_BYTES; i++ ) {//read image byte array\r\n\t\tfor (j=0;j<img1[i];j++){//write current byte to screen\r\n\r\n\t\t\tif (c==0x01){\r\n\t\t\t\tu8g_DrawPixel(&u8g,x,y);\r\n\t\t\t}\r\n\t\t\tif(x<fx+IMG_LENGTH-1){\r\n\t\t\t\tx++;\r\n\t\t\t}else{\r\n\t\t\t\tx=fx;\r\n\t\t\t\ty=y+1;\r\n\t\t\t}\r\n\t\t}\r\n\t\tc=c^0x01;//toggle color\r\n\t}");
  codeArea.append ("\r\n}");
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

/*listener for the copy to clipboard button*/
public class ButtonListener implements ActionListener
{
  public void actionPerformed(ActionEvent e)
  {
    StringSelection stringSelection = new StringSelection(codeArea.getText());
    Clipboard clpbrd = Toolkit.getDefaultToolkit().getSystemClipboard();
    clpbrd.setContents(stringSelection, null);
  }
}

/*
// unescaped draw method
 uint8_t c=0x01;//color code for the first color in the RLE (0x00: black, 0x01:white)
 uint16_t i;
 uint8_t j;
 for( i = 0; i < RLE_BYTES; i++ ) {//read image byte array
 
 for (j=0;j<img1[i];j++){//write current byte to screen
 
 if (c==0x01){
 u8g_DrawPixel(&u8g,fx,fy);
 }
 if(fx<IMG_LENGTH-1){
 fx++;
 }else{
 fx=0;
 fy=fy+1;
 }
 }
 c=c^0x01;//toggle color
 }
 
 */