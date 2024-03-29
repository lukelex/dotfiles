#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_all(
      KC_ESC,  KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,    KC_6,       KC_7,    KC_8,    KC_9,    KC_0,    KC_MINS,       KC_EQL,  KC_BSLS, KC_DEL,  KC_HOME,
      KC_DEL,  KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,    KC_Y,       KC_U,    KC_I,    KC_O,    KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,          KC_PGUP,
      KC_PGUP, LCTL_T(KC_ESC),   KC_A,       KC_S,    KC_D,          KC_F,    KC_G,    KC_H,       KC_J,    KC_K,    KC_L,    KC_SCLN, KC_QUOT,                KC_ENT,           KC_PGDN,
      KC_PGDN, KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,    KC_N,       KC_M,    KC_COMM, KC_DOT,  KC_SLSH,                KC_RSFT,          KC_UP,   KC_END,
      MO(4),   KC_LALT,          KC_LALT,    KC_LGUI,                                  LT(2, KC_SPC),                MO(3),   MO(4),   XXXXXXX,                KC_LEFT, KC_DOWN, KC_RGHT
  ),

  [1] = LAYOUT_all(
      _______, _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______, _______, _______,       _______, _______, _______, _______,
      _______, _______,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______, _______, _______,       _______, KC_DEL,           _______,
      _______, KC_LCTL,          _______,    _______, _______,       _______, _______, _______,    _______, _______, _______, _______, _______,                _______,          _______,
      _______, _______, XXXXXXX, _______,    _______, _______,       _______, _______, _______,    _______, _______, _______, _______,                _______,          _______, _______,
      _______, _______,          _______,    _______,                                  KC_SPC,                       _______, _______, _______,                _______, _______, _______
  ),

  [2] = LAYOUT_all(
      _______, _______,          KC_F1,      KC_F2,   KC_F3,         KC_F4,   KC_F5,   KC_F6,      KC_F7,   KC_F8,   KC_F9,   KC_F10,  KC_F11,        KC_F12,  _______, _______, _______,
      _______, _______,          _______,    KC_UP,   _______,       _______, _______, _______,    _______, _______, _______, _______, KC_VOLD,       KC_VOLU, KC_DEL,           _______,
      _______, _______,          KC_LEFT,    KC_DOWN, KC_RGHT,       _______, _______, KC_LEFT,    KC_DOWN, KC_UP,   KC_RGHT, _______, _______,                _______,          _______,
      _______, _______, XXXXXXX, _______,    _______, _______,       _______, _______, _______,    _______, KC_MPRV, KC_MNXT, KC_MPLY,                _______,          _______, _______,
      _______, _______,          _______,    _______,                                  _______,                      _______, _______, _______,                _______, _______, _______
  ),

  [3] = LAYOUT_all(
      _______, RALT(KC_N),       _______,    _______, _______,       _______, _______, RALT(KC_I), _______, _______, _______, _______, LGUI(KC_MINS), _______, _______, KC_ESC,  _______,
      _______, _______,          _______,    _______, RALT(KC_QUOT), _______, _______, _______,    _______, _______, _______, _______, _______,       _______, _______,          _______,
      _______, KC_CAPS,          RALT(KC_A), _______, _______,       _______, _______, _______,    _______, _______, _______, _______, RALT(KC_E),             _______,          _______,
      _______, _______, XXXXXXX, _______,    _______, RALT(KC_C),    _______, _______, _______,    _______, _______, _______, _______,                _______,          _______, _______,
      _______, _______,          _______,    _______,                                  _______,                      _______, _______, _______,                _______, _______, _______
  ),

  [4] = LAYOUT_all(
      RESET,   XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX, TG(1),
      RGB_TOG, RGB_HUI,          RGB_SAI,    RGB_VAI, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,          XXXXXXX,
      RGB_MOD, RGB_HUD,          RGB_SAD,    RGB_VAD, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                XXXXXXX,          XXXXXXX,
      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                XXXXXXX,          XXXXXXX, XXXXXXX,
      XXXXXXX, XXXXXXX,          XXXXXXX,    XXXXXXX,                                  XXXXXXX,                      XXXXXXX, _______, XXXXXXX,                XXXXXXX, XXXXXXX, XXXXXXX
  ),
};

bool led_update_user(led_t led_state) {
  // Turn LEDs On/Off for Caps Lock
  if (led_state.caps_lock) {
    rgblight_enable_noeeprom();
    rgblight_sethsv_noeeprom(HSV_WHITE);
  } else {
    rgblight_sethsv_noeeprom(HSV_WHITE);
    rgblight_disable_noeeprom();
  }
  return false;
}
