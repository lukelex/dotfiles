#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
[0] = LAYOUT_tkl_ansi(
  KC_ESC,           KC_F1,      KC_F2,   KC_F3,         KC_F4,   KC_F5,   KC_F6,      KC_F7,   KC_F8,   KC_F9,       KC_F10,     KC_F11,        KC_F12,           KC_MPRV, KC_MPLY, KC_MNXT,
  KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,    KC_6,       KC_7,    KC_8,    KC_9,        KC_0,       KC_MINS,       KC_EQL,  KC_BSPC, KC_INS,  KC_HOME, KC_PGUP,
  KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,    KC_Y,       KC_U,    KC_I,    KC_O,        KC_P,       KC_LBRC,       KC_RBRC, KC_BSLS, KC_DEL,  KC_END,  KC_PGDN,
  LCTL_T(KC_ESC),   KC_A,       KC_S,    KC_D,          KC_F,    KC_G,    KC_H,       KC_J,    KC_K,    KC_L,        KC_SCLN,    KC_QUOT,                KC_ENT,
  KC_LSFT,          KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,    KC_N,       KC_M,    KC_COMM, KC_DOT,      KC_SLSH,    KC_RSFT,                                  KC_UP,
  KC_LALT,          XXXXXXX,    KC_LGUI,                                  LT(2, KC_SPC),                             _______,    MO(3),         XXXXXXX, MO(4),   KC_LEFT, KC_DOWN, KC_RGHT),

[1] = LAYOUT_tkl_ansi(
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,       _______,          _______, _______, _______,
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,       _______, _______, _______, _______, _______,
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,       _______, _______, _______, _______, _______,
  KC_LCTL,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,                _______,
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,                                  _______,
  _______,          _______,    _______,                                  KC_SPC,                                    _______,    _______,       _______, _______, _______, _______, _______),

[2] = LAYOUT_tkl_ansi(
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,       _______,          _______, _______, _______,
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,       _______, _______, _______, _______, _______,
  _______,          _______,    KC_UP,   _______,       _______, _______, _______,    _______, _______, _______,     KC_PSCR,    _______,       _______, _______, _______, _______, _______,
  _______,          KC_LEFT,    KC_DOWN, KC_RIGHT,      _______, _______, KC_LEFT,    KC_DOWN, KC_UP,   KC_RIGHT,    _______,    _______,                _______,
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, KC_MPRV, KC_MNXT,     KC_MPLY,    _______,                                  _______,
  _______,          _______,    _______,                                  _______,                                   _______,    _______,       _______, _______, _______, _______, _______),

[3] = LAYOUT_tkl_ansi(
  _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    _______,       _______,          _______, _______, _______,
  RALT(KC_N),       _______,    _______, _______,       _______, _______, RALT(KC_I), _______, _______, _______,     _______,    LGUI(KC_MINS), _______, _______, _______, _______, _______,
  _______,          _______,    _______, RALT(KC_QUOT), _______, _______, _______,    _______, _______, RALT(KC_O),  _______,    _______,       _______, _______, _______, _______, _______,
  _______,          RALT(KC_A), _______, _______,       _______, _______, _______,    _______, _______, _______,     _______,    RALT(KC_E),             _______,
  _______,          _______,    _______, RALT(KC_C),    _______, _______, _______,    _______, _______, _______,     _______,    _______,                                  _______,
  _______,          _______,    _______,                                  _______,                                   _______,    _______,       _______, _______, _______, _______, _______),

[4] = LAYOUT_tkl_ansi(
  RESET,            XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,     XXXXXXX,    XXXXXXX,       XXXXXXX,          XXXXXXX, XXXXXXX, TG(1),
  XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,     XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
  XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,     XXXXXXX,    XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
  XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,     XXXXXXX,    XXXXXXX,                XXXXXXX,
  XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,     XXXXXXX,    XXXXXXX,                                  XXXXXXX,
  XXXXXXX,          XXXXXXX,    XXXXXXX,                                  XXXXXXX,                                   XXXXXXX,    XXXXXXX,       XXXXXXX, _______, XXXXXXX, XXXXXXX, XXXXXXX)
};
