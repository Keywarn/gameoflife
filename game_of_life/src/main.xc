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
#define ITER  1                  //no. iterations

typedef unsigned char uchar;

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

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

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////

//MOD is really slow
uchar mod(uchar val, int dval, uchar divisor) {
    if(dval > 1 || dval < -1) {
        printf("Incorrect dval used, shutting down");
        exit(1);
    }
    if(val == 0 && dval == -1) return(divisor-1);
    if(val == divisor-1 && dval == 1) return(0);
    return(val + dval);
}

void modTest(){
    assert (mod(10,1,11) == 0);
    assert (mod(5, 1, 10) == 6);
    assert (mod(0,-1,10) == 9);
}

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
    //printf("\nWORKER: ended!");
}

void farmerNew (chanend dist[], uchar endMap[IMHT][IMWD]) {
    // SETUP
    // receive map
    uchar newMap[SPLIT][PART_SIZE][IMWD];

    // LOOP
    for (int i=0; i<ITER; i++) {
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
    //printf("\nFARMER: ended!");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend fromAcc)
{
  uchar val;

  // for timing
  unsigned int _setup, _loop, _end,
                setup,  loop,  end;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  //fromAcc :> int value; //PUT THIS LINE BACK FOR TILT

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
    farmerNew(dist, endMap);
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
  /*for (int y=0; y < IMHT; y++) {
      for (int x=0; x < IMWD; x++) {
          printf("%d,\t", endMap[y][x]);
      }
      printf("\n");
  }*/

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
        (setup)/1000000,
        (loop)/1000000,
        (end)/1000000,
        (_end - time)/1000000);

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
    modTest();

    i2c_master_if i2c[1];               //interface to orientation

    char infname[] = "test.pgm";     //put your input image path here
    char outfname[] = "testout.pgm"; //put your output image path here
    chan c_inIO, c_outIO, c_control;    //extend your channel definitions here

    par {
        i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
        orientation(i2c[0],c_control);        //client thread reading orientation data
        DataInStream(infname, c_inIO);          //thread to read in a PGM image
        DataOutStream(outfname, c_outIO);       //thread to write out a PGM image
        distributor(c_inIO, c_outIO, c_control);//thread to coordinate work on image
      }

      return 0;
}
