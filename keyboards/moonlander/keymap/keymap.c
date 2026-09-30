#include QMK_KEYBOARD_H
#include "version.h"
#include "colours.h"
#define MOON_LED_LEVEL LED_LEVEL
#ifndef ZSA_SAFE_RANGE
#define ZSA_SAFE_RANGE SAFE_RANGE
#endif

enum custom_keycodes {
  RGB_SLD = ZSA_SAFE_RANGE,
  ST_MACRO_0,
};



enum tap_dance_codes {
  DANCE_0,
};

#define DUAL_FUNC_0 LT(9, KC_F5)
#define DUAL_FUNC_1 LT(4, KC_F1)

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_moonlander(
    KC_ESCAPE,      KC_1,           KC_2,           KC_3,           KC_4,           KC_5,           KC_TILD,                                        KC_AUDIO_VOL_UP,KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_BSPC,        
    CW_TOGG,        KC_Q,           KC_W,           KC_E,           KC_R,           KC_T,           RGB_TOG,                                        TD(DANCE_0),    KC_Y,           KC_U,           KC_I,           KC_O,           KC_P,           KC_MINUS,       
    KC_TAB,         MT(MOD_LSFT, KC_A),KC_S,           KC_D,           KC_F,           KC_G,           KC_PGDN,                                                                        KC_PAGE_UP,     KC_H,           KC_J,           KC_K,           KC_L,           MT(MOD_RSFT, KC_SCLN),KC_QUOTE,       
    MT(MOD_LSFT, KC_ENTER),MT(MOD_LGUI, KC_Z),KC_X,           KC_C,           KC_V,           KC_B,                                           KC_N,           KC_M,           KC_COMMA,       KC_DOT,         MT(MOD_RGUI, KC_SLASH),MT(MOD_RSFT, KC_ENTER),
    KC_LEFT_CTRL,   TT(3),          KC_LEFT_ALT,    KC_LEFT_GUI,    MO(1),          LGUI(KC_C),                                                                                                     LGUI(KC_V),     TT(2),          KC_RIGHT_GUI,   KC_RIGHT_ALT,   TG(3),          KC_RIGHT_CTRL,  
    MT(MOD_LSFT, KC_SPACE),MT(MOD_LGUI, KC_ENTER),TT(1),                          ST_MACRO_0,     MT(MOD_RGUI, KC_ENTER),KC_BSPC
  ),
  [1] = LAYOUT_moonlander(
    KC_ESCAPE,      KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_BSPC,        
    KC_TRANSPARENT, KC_EXLM,        KC_AT,          KC_LCBR,        KC_RCBR,        KC_AMPR,        KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_PIPE,        KC_GRAVE,       KC_TILD,        KC_BSLS,        KC_TRANSPARENT, 
    KC_TAB,         DUAL_FUNC_0,    KC_DLR,         KC_LPRN,        KC_RPRN,        KC_ASTR,        KC_TRANSPARENT,                                                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_PLUS,        KC_MINUS,       KC_EQUAL,       MT(MOD_RSFT, KC_SCLN),KC_QUOTE,       
    KC_LEFT_SHIFT,  DUAL_FUNC_1,    KC_CIRC,        KC_LBRC,        KC_RBRC,        KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_UNDS,        KC_COMMA,       KC_DOT,         MT(MOD_RGUI, KC_SLASH),KC_RIGHT_SHIFT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_LEFT_GUI,    KC_TRANSPARENT, KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, MO(3),          KC_RIGHT_GUI,   KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [2] = LAYOUT_moonlander(
    KC_TRANSPARENT, KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,          KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_F6,          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_F11,         
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_MS_UP,       KC_MS_WH_UP,    KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_UP,          KC_TRANSPARENT, KC_TRANSPARENT, KC_F12,         
    KC_TRANSPARENT, KC_LEFT_SHIFT,  KC_MS_LEFT,     KC_MS_DOWN,     KC_MS_RIGHT,    KC_TRANSPARENT, KC_TRANSPARENT,                                                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_LEFT,        KC_DOWN,        KC_RIGHT,       KC_RIGHT_SHIFT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_LEFT_GUI,    KC_MS_WH_LEFT,  KC_MS_WH_RIGHT, KC_MS_WH_DOWN,  KC_MS_BTN2,                                     KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_RIGHT_GUI,   KC_TRANSPARENT, 
    KC_LEFT_CTRL,   KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_MS_BTN1,     RGB_MODE_FORWARD,                                                                                                RGB_TOG,        KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_RIGHT_CTRL,  
    KC_MS_BTN1,     KC_MS_BTN2,     KC_TRANSPARENT,                 MOON_LED_LEVEL, RGB_VAD,        RGB_VAI
  ),
  [3] = LAYOUT_moonlander(
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,          KC_F6,                                          KC_LEFT_GUI,    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_1,           KC_2,           KC_3,           KC_4,           KC_5,           KC_TRANSPARENT,                                                                 KC_TRANSPARENT, KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT
  ),
};





extern rgb_config_t rgb_matrix_config;

RGB hsv_to_rgb_with_value(HSV hsv) {
  RGB rgb = hsv_to_rgb( hsv );
  float f = (float)rgb_matrix_config.hsv.v / UINT8_MAX;
  return (RGB){ f * rgb.r, f * rgb.g, f * rgb.b };
}

void keyboard_post_init_user(void) {
  rgb_matrix_enable();
  rgb_matrix_mode_noeeprom(RGB_MATRIX_CYCLE_LEFT_RIGHT);
}

void set_layer_color(int layer) {
  for (uint8_t row = 0; row < MATRIX_ROWS; row++) {
    for (uint8_t col = 0; col < MATRIX_COLS; col++) {
      uint8_t led = g_led_config.matrix_co[row][col];
      if (led == NO_LED) continue;
      uint8_t c = pgm_read_byte(&colours[layer][row][col]);
      if (c == ANIM) continue;
      HSV hsv = {
        .h = pgm_read_byte(&palette[c][0]),
        .s = pgm_read_byte(&palette[c][1]),
        .v = pgm_read_byte(&palette[c][2]),
      };
      if (!hsv.h && !hsv.s && !hsv.v) {
        rgb_matrix_set_color(led, 0, 0, 0);
      } else {
        RGB rgb = hsv_to_rgb_with_value(hsv);
        rgb_matrix_set_color(led, rgb.r, rgb.g, rgb.b);
      }
    }
  }
}

bool rgb_matrix_indicators_user(void) {
  if (rawhid_state.rgb_control) {
      return false;
  }
  if (!keyboard_config.disable_layer_led) { 
    switch (biton32(layer_state)) {
      case 0:
        set_layer_color(0);
        break;
      case 1:
        set_layer_color(1);
        break;
      case 2:
        set_layer_color(2);
        break;
      case 3:
        set_layer_color(3);
        break;
     default:
        if (rgb_matrix_get_flags() == LED_FLAG_NONE) {
          rgb_matrix_set_color_all(0, 0, 0);
        }
    }
  } else {
    if (rgb_matrix_get_flags() == LED_FLAG_NONE) {
      rgb_matrix_set_color_all(0, 0, 0);
    }
  }

  return true;
}


typedef struct {
    bool is_press_action;
    uint8_t step;
} tap;

enum {
    SINGLE_TAP = 1,      
    SINGLE_HOLD,         
    DOUBLE_TAP,          
    DOUBLE_HOLD,         
    DOUBLE_SINGLE_TAP,   
    MORE_TAPS            
};

static tap dance_state[1];

uint8_t dance_step(tap_dance_state_t *state);

uint8_t dance_step(tap_dance_state_t *state) {
    if (state->count == 1) {
        if (state->interrupted || !state->pressed) return SINGLE_TAP;
        else return SINGLE_HOLD;
    } else if (state->count == 2) {
        if (state->interrupted) return DOUBLE_SINGLE_TAP;
        else if (state->pressed) return DOUBLE_HOLD;
        else return DOUBLE_TAP;
    }
    return MORE_TAPS;
}


void on_dance_0(tap_dance_state_t *state, void *user_data);
void dance_0_finished(tap_dance_state_t *state, void *user_data);
void dance_0_reset(tap_dance_state_t *state, void *user_data);

void on_dance_0(tap_dance_state_t *state, void *user_data) {
    if(state->count == 3) {
        tap_code16(KC_AUDIO_VOL_DOWN);
        tap_code16(KC_AUDIO_VOL_DOWN);
        tap_code16(KC_AUDIO_VOL_DOWN);
    }
    if(state->count > 3) {
        tap_code16(KC_AUDIO_VOL_DOWN);
    }
}

void dance_0_finished(tap_dance_state_t *state, void *user_data) {
    dance_state[0].step = dance_step(state);
    switch (dance_state[0].step) {
        case SINGLE_TAP: register_code16(KC_AUDIO_VOL_DOWN); break;
        case DOUBLE_TAP: register_code16(KC_AUDIO_MUTE); break;
        case DOUBLE_SINGLE_TAP: tap_code16(KC_AUDIO_VOL_DOWN); register_code16(KC_AUDIO_VOL_DOWN);
    }
}

void dance_0_reset(tap_dance_state_t *state, void *user_data) {
    wait_ms(10);
    switch (dance_state[0].step) {
        case SINGLE_TAP: unregister_code16(KC_AUDIO_VOL_DOWN); break;
        case DOUBLE_TAP: unregister_code16(KC_AUDIO_MUTE); break;
        case DOUBLE_SINGLE_TAP: unregister_code16(KC_AUDIO_VOL_DOWN); break;
    }
    dance_state[0].step = 0;
}

tap_dance_action_t tap_dance_actions[] = {
        [DANCE_0] = ACTION_TAP_DANCE_FN_ADVANCED(on_dance_0, dance_0_finished, dance_0_reset),
};

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  switch (keycode) {
  case QK_MODS ... QK_MODS_MAX:
    // Mouse and consumer keys (volume, media) with modifiers work inconsistently across operating systems,
    // this makes sure that modifiers are always applied to the key that was pressed.
    if (IS_MOUSE_KEYCODE(QK_MODS_GET_BASIC_KEYCODE(keycode)) || IS_CONSUMER_KEYCODE(QK_MODS_GET_BASIC_KEYCODE(keycode))) {
      if (record->event.pressed) {
        add_mods(QK_MODS_GET_MODS(keycode));
        send_keyboard_report();
        wait_ms(2);
        register_code(QK_MODS_GET_BASIC_KEYCODE(keycode));
        return false;
      } else {
        wait_ms(2);
        del_mods(QK_MODS_GET_MODS(keycode));
      }
    }
    break;
    case ST_MACRO_0:
    if (record->event.pressed) {
      SEND_STRING(SS_LALT(SS_TAP(X_BSPC) ));
    }
    break;

    case DUAL_FUNC_0:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_HASH);
        } else {
          unregister_code16(KC_HASH);
        }
      } else {
        if (record->event.pressed) {
          register_code16(KC_LEFT_SHIFT);
        } else {
          unregister_code16(KC_LEFT_SHIFT);
        }  
      }  
      return false;
    case DUAL_FUNC_1:
      if (record->tap.count > 0) {
        if (record->event.pressed) {
          register_code16(KC_PERC);
        } else {
          unregister_code16(KC_PERC);
        }
      } else {
        if (record->event.pressed) {
          register_code16(KC_LEFT_GUI);
        } else {
          unregister_code16(KC_LEFT_GUI);
        }  
      }  
      return false;
    case RGB_SLD:
        if (rawhid_state.rgb_control) {
            return false;
        }
        if (record->event.pressed) {
            rgblight_mode(1);
        }
        return false;
  }
  return true;
}

