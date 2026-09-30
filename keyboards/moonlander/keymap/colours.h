#pragma once

// HSV, each 0-255. Hue: 0 red, 21 orange, 43 yellow, 85 green, 128 cyan, 170 blue, 213 magenta.
enum colour {
  OFF,
  BLUE,
  SKY,
  CREAM,
  AMBER,
  EMBER,
  TEAL,
  PLUM,
  MAGENTA,
  ORCHID,
  ROSE,
  RED,
  GREEN,
  ANIM, // no colour: the key shows the running RGB effect
};

static const uint8_t PROGMEM palette[][3] = {
  [OFF]     = {  0,   0,   0},
  [BLUE]    = {157, 218, 204},
  [SKY]     = {147, 168, 255},
  [CREAM]   = { 35,  28, 255},
  [AMBER]   = { 26, 194, 251},
  [EMBER]   = {  7, 183, 254},
  [TEAL]    = {124,  81, 225},
  [PLUM]    = {207, 218, 204},
  [MAGENTA] = {214, 218, 204},
  [ORCHID]  = {220, 117, 255},
  [ROSE]    = {220, 151, 253},
  [RED]     = { 10, 253, 255},
  [GREEN]   = { 98, 218, 204},
};

// One grid per layer, key for key with keymaps[] in keymap.c.
static const uint8_t PROGMEM colours[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_moonlander(
    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,       ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,
    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,       ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,
    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,       ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,
    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,                ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,
    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,                ANIM,    ANIM,    ANIM,    ANIM,    ANIM,    ANIM,
                                        ANIM,    ANIM,    ANIM,       ANIM,    ANIM,    ANIM
  ),
  [1] = LAYOUT_moonlander(
    SKY,     OFF,     OFF,     OFF,     OFF,     OFF,     OFF,        OFF,     OFF,     OFF,     OFF,     OFF,     OFF,     SKY,
    OFF,     AMBER,   AMBER,   EMBER,   EMBER,   AMBER,   OFF,        OFF,     OFF,     AMBER,   AMBER,   AMBER,   AMBER,   OFF,
    CREAM,   AMBER,   AMBER,   EMBER,   EMBER,   AMBER,   OFF,        OFF,     OFF,     AMBER,   AMBER,   AMBER,   AMBER,   AMBER,
    CREAM,   AMBER,   AMBER,   EMBER,   EMBER,   OFF,                 OFF,     AMBER,   AMBER,   AMBER,   AMBER,   CREAM,
    OFF,     OFF,     OFF,     CREAM,   OFF,     SKY,                 SKY,     CREAM,   CREAM,   OFF,     OFF,     OFF,
                                        EMBER,   EMBER,   OFF,        EMBER,   EMBER,   EMBER
  ),
  [2] = LAYOUT_moonlander(
    OFF,     TEAL,    TEAL,    TEAL,    TEAL,    TEAL,    OFF,        OFF,     TEAL,    TEAL,    TEAL,    TEAL,    TEAL,    TEAL,
    OFF,     OFF,     OFF,     MAGENTA, ORCHID,  OFF,     OFF,        OFF,     OFF,     OFF,     RED,     OFF,     OFF,     TEAL,
    OFF,     CREAM,   PLUM,    PLUM,    PLUM,    OFF,     OFF,        OFF,     OFF,     RED,     RED,     RED,     CREAM,   OFF,
    OFF,     CREAM,   ORCHID,  ORCHID,  ORCHID,  ROSE,                OFF,     OFF,     OFF,     OFF,     CREAM,   OFF,
    CREAM,   OFF,     OFF,     OFF,     ROSE,    OFF,                 OFF,     OFF,     OFF,     OFF,     OFF,     CREAM,
                                        ROSE,    ROSE,    OFF,        OFF,     OFF,     OFF
  ),
  [3] = LAYOUT_moonlander(
    OFF,     OFF,     OFF,     OFF,     OFF,     OFF,     OFF,        OFF,     OFF,     OFF,     OFF,     OFF,     OFF,     OFF,
    OFF,     OFF,     OFF,     OFF,     OFF,     OFF,     OFF,        OFF,     OFF,     OFF,     OFF,     OFF,     OFF,     OFF,
    OFF,     GREEN,   GREEN,   GREEN,   GREEN,   GREEN,   OFF,        OFF,     GREEN,   GREEN,   GREEN,   GREEN,   GREEN,   OFF,
    OFF,     OFF,     OFF,     OFF,     OFF,     OFF,                 OFF,     OFF,     OFF,     OFF,     OFF,     OFF,
    OFF,     OFF,     OFF,     OFF,     OFF,     OFF,                 OFF,     OFF,     OFF,     OFF,     OFF,     OFF,
                                        OFF,     OFF,     OFF,        OFF,     OFF,     OFF
  ),
};
