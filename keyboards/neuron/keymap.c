#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT(
      KC_TAB,         KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,       KC_Y,          KC_U,    KC_I,     KC_O,       KC_P,           KC_BSPC,
      LCTL_T(KC_ESC), KC_A,       KC_S,    KC_D,          KC_F,    KC_G,       KC_H,          KC_J,    KC_K,     KC_L,       KC_SCLN,
      KC_LSFT,        KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,       KC_N,          KC_M,    KC_COMM,  KC_DOT,     LT(3, KC_SLSH),
                      KC_LALT,    KC_LGUI, KC_SPC,                 XXXXXXX,    LT(2, KC_ENT), MO(4),   MO(5)),

  [1] = LAYOUT(
      KC_TAB,         KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,       KC_Y,          KC_U,    KC_I,     KC_O,       KC_P,           KC_BSPC,
      KC_LCTL,        KC_A,       KC_S,    KC_D,          KC_F,    KC_G,       KC_H,          KC_J,    KC_K,     KC_L,       KC_SCLN,
      KC_LSFT,        KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,       KC_N,          KC_M,    KC_COMM,  KC_DOT,     MO(3),
                      KC_LALT,    KC_LGUI, KC_SPC,                 XXXXXXX,    LT(2, KC_ENT), MO(4),   MO(5)),

  [2] = LAYOUT(
      KC_GRV,         KC_1,       KC_2,    KC_3,          KC_4,    KC_5,       KC_6,          KC_7,    KC_8,     KC_9,       KC_0,           KC_DEL,
      KC_LCTL,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    KC_LEFT,       KC_DOWN, KC_UP,    KC_RIGHT,   KC_QUOT,
      KC_LSFT,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, KC_MPRV,  KC_MNXT,    KC_MPLY,
                      KC_LALT,    KC_LGUI, KC_SPC,                 XXXXXXX,    _______,       MO(4),   MO(5)),

  [3] = LAYOUT(
      KC_F1,          KC_F2,      KC_F3,   KC_F4,         KC_F5,   KC_F6,      KC_F7,         KC_F8,   KC_F9,    KC_F10,     KC_F11,         KC_F12,
      KC_LCTL,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    KC_MINS,       KC_EQL,  KC_LBRC,  KC_RBRC,    KC_BSLS,
      KC_LSFT,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX,  XXXXXXX,    _______,
                      KC_LALT,    KC_LGUI, KC_SPC,                 XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX),

  [4] = LAYOUT(
      RALT(KC_N),     XXXXXXX,    XXXXXXX, RALT(KC_QUOT), XXXXXXX, XXXXXXX, RALT(KC_I),       XXXXXXX, XXXXXXX,  RALT(KC_O),  KC_PSCR,       LGUI(KC_MINS),
      KC_LCTL,        RALT(KC_A), XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX,  XXXXXXX,     RALT(KC_E),
      KC_LSFT,        XXXXXXX,    XXXXXXX, RALT(KC_C),    XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX,  XXXXXXX,     _______,
                      KC_LALT,    KC_LGUI, KC_SPC,                 XXXXXXX,    XXXXXXX,       _______, XXXXXXX),

  [5] = LAYOUT(
      RESET,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX,  XXXXXXX,     XXXXXXX,       TG(1),
      XXXXXXX,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX,  XXXXXXX,     XXXXXXX,
      XXXXXXX,        XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX,  XXXXXXX,     XXXXXXX,
                      XXXXXXX,    XXXXXXX, XXXXXXX,                XXXXXXX,    XXXXXXX,       XXXXXXX, _______)
};
