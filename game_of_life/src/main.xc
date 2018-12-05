// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"
//#include "mod.h"
#include "assert.h"

#define IMHT 16                  //image height
#define IMWD 16                  //image width
#define SPLIT  4                 //how many parts to split the height into
#define PART_SIZE (IMHT / SPLIT) //height of the part
#define ITER  2                  //no. iterations

#define OUTFNAME "testout.pgm"
#define INFNAME "test.pgm"

typedef unsigned char uchar;

on tile[0]: port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0]: port p_sda = XS1_PORT_1F;
on tile[0] : in port buttons = XS1_PORT_4E;
on tile[0] : out port leds = XS1_PORT_4F;//port for buttons

// led colours
#define LED_GREEN_SEP 1
#define LED_GREEN 4

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

enum direction {above, aboveRight, right, belowRight, below, belowLeft, left, aboveLeft};
typedef enum direction direction;
dirMod[8][2] = {{1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1},{0,-1},{1,-1}};

enum state {alive = 255, dead = 0};
typedef enum state state;



uchar mod(uchar val, int dval, uchar divisor) {
    if(dval > 1 || dval < -1) {
        printf("Incorrect dval used, shutting down");
        exit(1);
    }
    if(val == 0 && dval == -1) return(divisor-1);
    if(val == divisor-1 && dval == 1) return(0);
    return(val + dval);
}

short packSection(uchar section[16]){
    short data = 0 & 1;
    for (int i = 0; i < 16; i++){
        data = data << 1 | (1 & (section[i] == 255 ? 1 : 0));
    }
    return data;
}

void packRow(uchar row[IMWD], short packedRow[IMWD/16]){
    uchar section[16];
    for (int sections = 0; sections < IMWD/16; sections++){
        for (int i = 0; i < 16; i++){
            section[i] = row[i];
        }
       packedRow[sections] = packSection(section);
    }
}

uchar getBitSection(short section, uchar relPos){
    return((section >> (15-relPos)) & 1);
}

uchar getBitRow(short row[IMWD/16],int pos){
    uchar sectionIndex = pos/16;

    return (getBitSection(row[sectionIndex], pos % 16));
}

void modTest(){
    assert (mod(10,1,11) == 0);
    assert (mod(5, 1, 10) == 6);
    assert (mod(0,-1,10) == 9);
}

void buttonListener(in port b, chanend buttChan) {
  int r;
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed
    if (r==14) buttChan <: r;             // start button pattern sent to distributor
  }
}

int ledManager(out port p, chanend ledChan) {
  uchar data;
  uchar sepGreen = 1;
  uchar blue = 2;
  uchar green = 4;
  uchar red = 8;

  int pattern = 0; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    ledChan :> data; //receive new pattern from visualiser
    pattern = pattern ^ data;
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////

void DataInStream(char infname[], chanend c_out) {
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
      //printf( "-%4.1d ", line[ x ] ); //show image values
    }
    //printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

int getNeighbour(uchar map[IMHT][IMWD], int y, int x, direction dir){
    return (map[mod(y,dirMod[dir][0], IMHT)][mod(x,dirMod[dir][1], IMWD)]) / alive;
}
int getNeighbours(uchar map[IMHT][IMWD], int y, int x) {
    int sum = 0;

    for (int i = 0; i < 8; i++){
        sum += getNeighbour(map, y, x, i);
    }

    return sum;
}

int getNeighbourRow(uchar row[IMWD], uchar above[IMWD], uchar below[IMWD], int dir, int val) {
    if (dirMod[dir][0] == 1) {
        return above[mod(val, dirMod[dir][1], IMWD)];
    }
    else if (dirMod[dir][0] == -1) {
        return below[mod(val, dirMod[dir][1], IMWD)];
    }
    else {
        return row[mod(val, dirMod[dir][1], IMWD)];
    }
}

int getNeighboursRow(uchar row[IMWD], uchar above[IMWD], uchar below[IMWD], int val) {
    int sum = 0;
    for (int dir = 0; dir < 8; dir++){
        sum += getNeighbourRow(row, above, below, dir, val);
        }
}

// where y is relative to PART_SIZE
int getNeighbourSplit(uchar section[PART_SIZE][IMWD], uchar above[], uchar below[], int dir, int x, int y) {
    if (y == 0 && dirMod[dir][0] == -1) {
        return above[mod(x, dirMod[dir][1], IMWD)] / alive;
    }
    else if (y == PART_SIZE - 1 && dirMod[dir][0] == 1) {
        return below[mod(x, dirMod[dir][1], IMWD)] / alive;
    }
    else {
        //printf("(%d, %d) -+> (,) -> (%d, %d)\n", x, y, mod(x, dirMod[dir][1], IMWD), y + dirMod[dir][0]);
        return section[y + dirMod[dir][0]][mod(x, dirMod[dir][1], IMWD)] / alive;
    }
}

int getNeighboursSplit(uchar row[PART_SIZE][IMWD], uchar above[], uchar below[], int x, int y) {
    int sum = 0;
    for (int dir=0; dir < 8; dir++)
        sum += getNeighbourSplit(row, above, below, dir, x, y);
    return sum;
}

unsigned char * alias worker (unsigned char above[IMWD], unsigned char below[IMWD], unsigned char row[IMWD]){
    uchar newRow[IMWD];
    for (int val = 0; val < IMWD; val++){
        newRow[val] = dead;
        int neighbours = getNeighboursRow(row, above, below, val);
        int isAlive = row[val] == alive;
        if (neighbours < 2 && isAlive) newRow[val] = dead;
        else if (isAlive && (neighbours == 2 || neighbours == 3)) newRow[val] = alive;
        else if(neighbours > 3 && isAlive) newRow[val] = dead;
        else if(neighbours == 3 && !isAlive) newRow[val] = alive;
    }
}

void workerNew (int part, chanend dist, uchar row[PART_SIZE][IMWD], uchar above[IMWD], uchar below[IMWD]) {
    /*
     * SETUP
     */

    // memcpy init. values into own
    uchar currentRow[PART_SIZE][IMWD], currentAbove[IMWD], currentBelow[IMWD];
    memcpy(&currentRow, &row, sizeof(row));
    memcpy(&currentAbove, &above, sizeof(above));
    memcpy(&currentBelow, &below, sizeof(below));

    /*
     * LOOP
     */
    uchar newRow[PART_SIZE][IMWD];

    for (int i=0; i<ITER; i++) {
        // process
        for (int y=0; y < PART_SIZE; y++) {
            for (int x=0; x < IMWD; x++) {
                newRow[y][x] = dead;
                int neighbours = getNeighboursSplit(currentRow, currentAbove, currentBelow, x, y);
                int isAlive = currentRow[y][x] == alive;

                if (neighbours < 2 && isAlive) newRow[y][x] = dead;
                else if (isAlive && (neighbours == 2 || neighbours == 3)) newRow[y][x] = alive;
                else if(neighbours > 3 && isAlive) newRow[y][x] = dead;
                else if(neighbours == 3 && !isAlive) newRow[y][x] = alive;
            }
        }

        // copy newRow -> current
        memcpy(&currentRow, &newRow, sizeof(newRow));

        // send row
        master {
            dist <: part;

            for (int y=0; y < PART_SIZE; y++) {
                for (int x=0; x < IMWD; x++) {
                    dist <: currentRow[y][x];
                }
            }
        }

        // receive rowTop & rowBototm
        slave {
            for (int x=0; x < IMWD; x++)
                dist :> currentAbove[x];
            for (int x=0; x < IMWD; x++)
                dist :> currentBelow[x];
        }
    }
}

void workerNew2 (int workerId, uchar part[PART_SIZE][IMWD], chanend farmer, chanend workAbove, chanend workBelow) {
    /*
     * SETUP
     */
    // memcpy into own
    uchar curPart[PART_SIZE][IMWD], curAbove[IMWD], curBelow[IMWD];
    memcpy(&curPart, &part, sizeof(part));

    /*
     * LOOP
     */
    for (int i=0; i < ITER; i++) {
        // if is even
        if(workerId % 2 == 0) {
            // send -> below
            for (int x=0; x < IMWD; x++) workBelow <: curPart[PART_SIZE-1][x];
            printf("WORKER %d: even; sent to below\n", workerId);
            // receive BOTTOM from below
            for (int x=0; x < IMWD; x++) workBelow :> curBelow[x];

            // send -> above
            for (int x=0; x < IMWD; x++) workAbove <: curPart[0][x];
            // receive TOP from above
            for (int x=0; x < IMWD; x++) workAbove :> curAbove[x];
        }else{
            // receive TOP from above
            for (int x=0; x < IMWD; x++) workAbove :> curAbove[x];
            printf("WORKER %d: odd; recieved from above\n", workerId);
            // send -> top
            for (int x=0; x < IMWD; x++) workAbove <: curPart[0][x];

            // receive BOTTOM from below
            for (int x=0; x < IMWD; x++) workBelow :> curBelow[x];
            // send -> below
            for (int x=0; x < IMWD; x++) workBelow <: curPart[PART_SIZE-1][x];
        }

        // process GoL
        uchar tempPart[PART_SIZE][IMWD];
        for (int y=0; y < PART_SIZE; y++) {
            for (int x=0; x < IMWD; x++) {
                tempPart[y][x] = dead;
                int neighbours = getNeighboursSplit(curPart, curAbove, curBelow, x, y);
                int isAlive = curPart[y][x] == alive;

                if (neighbours < 2 && isAlive) tempPart[y][x] = dead;
                else if (isAlive && (neighbours == 2 || neighbours == 3)) tempPart[y][x] = alive;
                else if(neighbours > 3 && isAlive) tempPart[y][x] = dead;
                else if(neighbours == 3 && !isAlive) tempPart[y][x] = alive;
            }
        }
        // copy tempPart -> current
        memcpy(&curPart, &tempPart, sizeof(tempPart));
    }

    /*
     * END or INTERRUPT
     */
    // send part -> dist
    for (int y=0; y < PART_SIZE; y++) {
        for (int x=0; x < IMWD; x++) {
            farmer <: curPart[y][x];
        }
    }
}

void farmerNew2 (chanend workers[], chanend c_out) {
    /*
     * SETUP
     */

    /*
     * LOOP
     */
    // wait for button press -> interrupt worker if so
    /*select {
        case buttChan :> int btn:
            printf("%d", btn);
    }*/

    /*
     * END
     */
    uchar map[IMHT][IMWD];
    // copy back map
    for (int s=0; s < SPLIT; s++) {
        int yOffset = s * SPLIT;
        for (int y=0; y < PART_SIZE; y++) {
            int actualY = y + yOffset;
            for (int x=0; x < IMWD; x++) {
                workers[s] :> map[actualY][x];
            }
        }
    }

    // print map
    for (int y=0; y < IMHT; y++) {
        for (int x=0; x < IMWD; x++) {
            printf("%d,\t", map[y][x]);
        }
        printf("\n");
    }

    // output image
    for( int y = 0; y < IMHT; y++ ) {
        for( int x = 0; x < IMWD; x++ ) {
            c_out <: map[y][x];
        }
    }
}

void distributorNew2 (chanend c_in, chanend c_out, chanend buttChan) {
    /*
     * SETUP
     */
    // read in map from image
    uchar map[IMHT][IMWD];
    for( int y = 0; y < IMHT; y++ ) {
      for( int x = 0; x < IMWD; x++ ) {
        c_in :> map[y][x];
      }
    }

    // split map into parts
    uchar mapParts[SPLIT][PART_SIZE][IMWD];
    for (int s=0; s < SPLIT; s++) {
        int yOffset = s * SPLIT;
        for (int y=0; y < PART_SIZE; y++) {
            int actualY = y + yOffset;
            memcpy(&mapParts[s][y], &map[actualY], sizeof(map[actualY]));
        }
    }

    // wait for button press
    //buttChan :> throw;

    /*
     * LOOP
     */
    // par statement w/ farmer & workers
    chan workers[SPLIT];
    chan btw0_1, btw0_3, btw1_2, btw2_3;
    par {
        farmerNew2(workers, c_out);
        workerNew2(0, mapParts[0], workers[0], btw0_3, btw0_1);
        workerNew2(1, mapParts[1], workers[1], btw0_1, btw1_2);
        workerNew2(2, mapParts[2], workers[2], btw1_2, btw2_3);
        workerNew2(3, mapParts[3], workers[3], btw2_3, btw0_3);
        /*par (int s=0; s < 4; s++) {
            workerNew2(s,
                       mapParts[s],
                       this,
                       workers[mod(s, -1, SPLIT)],
                       workers[mod(s, 1, SPLIT)]);
        }*/
    }

    /*
     * END
     */
}

void farmerNew (chanend dist[], chanend ledChan, uchar endMap[IMHT][IMWD]) {
    // SETUP
    // receive map
    uchar newMap[SPLIT][PART_SIZE][IMWD];

    // LOOP
    for (int i=0; i<ITER; i++) {
        ledChan <: (uchar) LED_GREEN_SEP;
        // receive row
        for (int i=0; i < SPLIT; i++) {
            slave {
                int part = 0;
                dist[i] :> part;

                for (int y=0; y < PART_SIZE; y++) {
                    for (int x=0; x < IMWD; x++) {
                        dist[i] :> newMap[part][y][x];
                    }
                }
            }
        }

        // TESTING: print arr
        /*for (int s=0; s < SPLIT; s++) {
            for (int y=0; y < PART_SIZE; y++) {
                for (int x=0; x < IMWD; x++) {
                    printf("%d, ", newMap[s][y][x]);
                }
                printf("\n");
            }
        }*/

        // send rowTop & rowBottom
        for (int s=0; s < SPLIT; s++) {
            master {
                // btm
                for (int x=0; x < IMWD; x++) {
                    dist[s] <: newMap[mod(s, -1, SPLIT)][PART_SIZE - 1][x];
                }
                // top
                for (int x=0; x < IMWD; x++) {
                    dist[s] <: newMap[mod(s, 1, SPLIT)][0][x];
                }
            }
        }
    }
    for (int s=0; s < SPLIT; s++) {
            for (int y=0; y < PART_SIZE; y++) {
                int actualY = PART_SIZE * s + y;

                for (int x=0; x < IMWD; x++) {
                    endMap[actualY][x] = newMap[s][y][x];
                }
            }
        }

    //printf("\nFARMER: ended!");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend buttChan, chanend ledChan)
{
  uchar val;

  // for timing
  unsigned int _setup, _loop, _end,
                setup,  loop,  end;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Button Press...\n" );
  int throw;
  //buttChan :> throw;
  ledChan <: (uchar) LED_GREEN;
  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  printf( "Processing...\n" );
  uchar map[IMHT][IMWD];

  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
      c_in :> val;                    //read the pixel value

      map[y][x] = val;
      //c_out <: (uchar)( val ^ 0xFF ); //send some modified pixel out
    }
  }

  ledChan <: (uchar) LED_GREEN;
  unsigned time;
  timer t;
  t :> time;

  /*
   * INITIAL STEP
   */
  chan dist[SPLIT];

  // split map into parts
  uchar mapParts[SPLIT][PART_SIZE][IMWD];
  for (int s=0; s < SPLIT; s++) {
      int yOffset = s * SPLIT;
      for (int y=0; y < PART_SIZE; y++) {
          int actualY = y + yOffset;
          memcpy(&mapParts[s][y], &map[actualY], sizeof(map[actualY]));
      }
  }
  // create arrays of separate bottom & top rows for each part
  uchar rowBtms[SPLIT][IMWD], rowTops[SPLIT][IMWD];
  for (int s=0; s < SPLIT; s++) {
      // bottom rows
      memcpy(&rowBtms[s],
             &mapParts[mod(s, -1, SPLIT)][PART_SIZE - 1],
             sizeof(mapParts[mod(s, -1, SPLIT)][PART_SIZE - 1]));
      // top rows
      memcpy(&rowTops[s],
             &mapParts[mod(s, 1, SPLIT)][0],
             sizeof(mapParts[mod(s, 1, SPLIT)][0]));
  }

  t :> _setup;

  /*
   * LOOP
   */
  // passed to farmer & copied to
  uchar endMap[IMHT][IMWD];

  par {
    farmerNew(dist, ledChan, endMap);
    par (int f=0; f < 4; f++) {
        workerNew(f,
                dist[f],
                mapParts[f],
                rowBtms[f],
                rowTops[f]);
    }
  }

  t :> _loop;

  // DEBUG PRINT STUFF
  for (int y=0; y < IMHT; y++) {
      for (int x=0; x < IMWD; x++) {
          printf("%d,\t", endMap[y][x]);
      }
      printf("\n");
  }

  // copy back map
  for( int y = 0; y < IMHT; y++ ) {
      for( int x = 0; x < IMWD; x++ ) {
          c_out <: endMap[y][x];
      }
  }

  t :> _end;

  setup = _setup - time;
  loop = _loop - _setup;
  end = _end - _loop;

  // TIME CHECK
  printf("\n--------\nTIME:\n* Setup: %d\n* Loop: %d\n* End: %d\n* TOTAL: %d\n",
        (setup)/100000,
        (loop)/100000,
        (end)/100000,
        (_end - time)/100000);

  printf("\n Output complete \n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
  int res;
  uchar line[ IMWD ];

  //Open PGM file
  printf( "DataOutStream: Start...\n" );
  res = _openoutpgm( outfname, IMWD, IMHT );
  if( res ) {
    printf( "DataOutStream: Error opening %s\n.", outfname );
    return;
  }

  //Compile each line of the image and write the image line-by-line
  for( int y = 0; y < IMHT; y++ ) {
    for( int x = 0; x < IMWD; x++ ) {
      c_in :> line[ x ];
    }
    _writeoutline( line, IMWD );
    //printf( "DataOutStream: Line written...\n" );         uncomment later
  }

  //Close the PGM image
  _closeoutpgm();
  printf( "DataOutStream: Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt

    if (!tilted) {
      //if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      //}
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {
    /*
    uchar testArray[32] = {0,255,0,255,255,255,0,0,255,0,0,0,255,0,0,255,0,255,0,255,255,255,0,0,255,0,0,0,255,0,0,255};
    short testShort[2];

    packRow(testArray, testShort);

    for(int i = 0; i < 32; i++){
        printf("i: %d -> %d\n", i, getBitRow(testShort, i));
    }
    */

    i2c_master_if i2c[1];               //interface to orientation

    //char infname[] = "test.pgm";     //put your input image path here
    //char outfname[] = "testout.pgm"; //put your output image path here
    chan c_inIO, c_outIO, c_control, buttChan, ledChan;    //extend your channel definitions here

    par {
        on tile[0]: buttonListener(buttons, buttChan);
        on tile[0]: ledManager(leds, ledChan);
        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
        on tile[0]: orientation(i2c[0],c_control);        //client thread reading orientation data
        on tile[0]: DataInStream(INFNAME, c_inIO);          //thread to read in a PGM image
        on tile[0]: DataOutStream(OUTFNAME, c_outIO);       //thread to write out a PGM image
        //on tile[1]: distributor(c_inIO, c_outIO, c_control, buttChan, ledChan);//thread to coordinate work on image
        on tile[1]: distributorNew2(c_inIO, c_outIO, buttChan);//thread to coordinate work on image
      }

      return 0;
}
