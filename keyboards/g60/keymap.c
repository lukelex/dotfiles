#include QMK_KEYBOARD_H

enum layer_names {
  _BASE,
  _GAMING,
  _FUNCTION,
  _SHORTCUTS,
  _FIRMWARE
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [_BASE] = LAYOUT_all(
      KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,    KC_6,          KC_7,    KC_8,    KC_9,       KC_0,           KC_MINS,       KC_EQL,        KC_BSLS,       KC_ESC,
      KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,    KC_Y,          KC_U,    KC_I,    KC_O,       KC_P,           KC_LBRC,       KC_RBRC,       KC_BSPC,
      LCTL_T(KC_ESC),   KC_A,       KC_S,    KC_D,          KC_F,    KC_G,    KC_H,          KC_J,    KC_K,    KC_L,       KC_SCLN,        KC_QUOT,       KC_BSLS,       KC_ENT,
      KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,    KC_N,          KC_M,    KC_COMM, KC_DOT,     KC_SLSH,                       KC_RSFT,                      MO(_FIRMWARE),
      KC_LALT,          KC_LALT,    KC_LALT, KC_LGUI,                         LT(2, KC_SPC),                   KC_RALT,    MO(_SHORTCUTS), KC_APP,        MO(_FIRMWARE),                MO(_FIRMWARE)),

  [_GAMING] = LAYOUT_all(
      KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,    KC_6,          KC_7,    KC_8,    KC_9,       KC_0,           KC_MINS,       KC_EQL,        KC_BSLS,       KC_ESC,
      KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,    KC_Y,          KC_U,    KC_I,    KC_O,       KC_P,           KC_LBRC,       KC_RBRC,       KC_BSPC,
      KC_LCTL,          KC_A,       KC_S,    KC_D,          KC_F,    KC_G,    KC_H,          KC_J,    KC_K,    KC_L,       KC_SCLN,        KC_QUOT,       KC_BSLS,       KC_ENT,
      KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,    KC_N,          KC_M,    KC_COMM, KC_DOT,     KC_SLSH,                       KC_RSFT,                      MO(_FIRMWARE),
      KC_LALT,          KC_LALT,    KC_LALT, KC_LGUI,                         KC_SPC,                          KC_RALT,    MO(_SHORTCUTS), KC_APP,        MO(_FIRMWARE),                XXXXXXX),

  [_FUNCTION] = LAYOUT_all(
      KC_GRV,           KC_F1,      KC_F2,   KC_F3,         KC_F4,   KC_F5,   KC_F6,         KC_F7,   KC_F8,   KC_F9,      KC_F10,         KC_F11,        KC_F12,        KC_BSLS,       KC_ESC,
      KC_TAB,           XXXXXXX,    KC_UP,   XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    KC_PSCR,        XXXXXXX,       XXXXXXX,       KC_DEL,
      KC_LCTL,          KC_LEFT,    KC_DOWN, KC_RIGHT,      XXXXXXX, XXXXXXX, KC_LEFT,       KC_DOWN, KC_UP,   KC_RIGHT,   XXXXXXX,        XXXXXXX,       XXXXXXX,       XXXXXXX,
      KC_LSFT, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, KC_MPRV, KC_MNXT,    KC_MPLY,                       KC_RSFT,                      XXXXXXX,
      KC_LALT,          KC_LALT,    KC_LALT, KC_LGUI,                         _______,                         XXXXXXX,    XXXXXXX,        XXXXXXX,       XXXXXXX,                      XXXXXXX),

  [_SHORTCUTS] = LAYOUT_all(
      RALT(KC_N),       XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, RALT(KC_I),    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,        LGUI(KC_MINS), XXXXXXX,       XXXXXXX,       LGUI(KC_ESC),
      XXXXXXX,          XXXXXXX,    XXXXXXX, RALT(KC_QUOT), XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, RALT(KC_O), XXXXXXX,        XXXXXXX,       XXXXXXX,       XXXXXXX,
      XXXXXXX,          RALT(KC_A), XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,        RALT(KC_E),    XXXXXXX,       XXXXXXX,
      XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, RALT(KC_C),    XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,                       XXXXXXX,                      XXXXXXX,
      XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,                         XXXXXXX,                         XXXXXXX,    _______,        XXXXXXX,       XXXXXXX,                      XXXXXXX),

  [_FIRMWARE] = LAYOUT_all(
      RESET,            XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,        XXXXXXX,       XXXXXXX,       XXXXXXX,       TG(1),
      RGB_TOG,          RGB_HUI,    RGB_SAI, RGB_VAI,       BL_INC,  XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,        XXXXXXX,       XXXXXXX,       XXXXXXX,
      RGB_MOD,          RGB_HUD,    RGB_SAD, RGB_VAD,       BL_DEC,  XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,        XXXXXXX,       XXXXXXX,       XXXXXXX,
      BL_TOGG, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,                       XXXXXXX,                      _______,
      XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,                         XXXXXXX,                         XXXXXXX,    XXXXXXX,        _______,       XXXXXXX,                      _______),
};
