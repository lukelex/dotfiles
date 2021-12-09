#include QMK_KEYBOARD_H

enum kaomojies {
  MEH = SAFE_RANGE,
  TABLE_FLIP,
  HUE,
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT_all(
        KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,       KC_6,       KC_7,    KC_8,    KC_9,    KC_0,    KC_MINS,       KC_EQL,   KC_BSLS, KC_HOME,
        KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,       KC_Y,       KC_U,    KC_I,    KC_O,    KC_P,    KC_LBRC,       KC_RBRC,  KC_BSPC, KC_PGUP,
        LCTL_T(KC_ESC),   KC_A,       KC_S,    KC_D,          KC_F,    KC_G,       KC_H,       KC_J,    KC_K,    KC_L,    KC_SCLN, KC_QUOT,       KC_ENT,   KC_ESC,  KC_PGDN,
        KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,       KC_N,       KC_M,    KC_COMM, KC_DOT,  KC_SLSH, KC_RSFT,                 KC_UP,   KC_END,
        KC_LALT,          KC_LALT,    KC_LGUI,                KC_SPC,              LT(2, KC_SPC),       KC_SPC,           MO(3),   MO(4),         KC_LEFT,  KC_DOWN, KC_RGHT
    ),

    [1] = LAYOUT_all(
        _______,          _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,       _______,  KC_ESC,  _______,
        _______,          _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,       _______,  _______, _______,
        KC_LCTL,          _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,       _______,  _______, _______,
        _______, _______, _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,                 _______, _______,
        _______,          _______,    _______,                _______,             KC_SPC,              _______,          _______, _______,       _______,  _______, _______
    ),

    [2] = LAYOUT_all(
        _______,          KC_F1,      KC_F2,   KC_F3,         KC_F4,   KC_F5,      KC_F6,      KC_F7,   KC_F8,   KC_F9,   KC_F10,  KC_F11,        KC_F12,   _______, _______,
        _______,          _______,    KC_UP,   _______,       _______, _______,    _______,    _______, _______, _______, KC_PSCR, _______,       _______,  KC_DEL, _______,
        _______,          KC_LEFT,    KC_DOWN, KC_RGHT,       _______, _______,    KC_LEFT,    KC_DOWN, KC_UP,   KC_RGHT, _______, _______,       _______,  _______, _______,
        _______, _______, _______,    _______, _______,       _______, _______,    _______,    _______, KC_MPRV, KC_MNXT, KC_MPLY, _______,                 _______, _______,
        _______,          _______,    _______,                _______,             _______,             _______,          _______, _______,       _______,  _______, _______
    ),

    [3] = LAYOUT_all(
        RALT(KC_N),       _______,    _______, _______,       _______, _______,    RALT(KC_I), _______, _______, _______, _______, LGUI(KC_MINS), _______,  _______, _______,
        _______,          _______,    _______, RALT(KC_QUOT), _______, TABLE_FLIP, _______,    _______, _______, _______, _______, _______,       _______,  _______, _______,
        _______,          RALT(KC_A), _______, _______,       _______, _______,    HUE,        _______, _______, _______, _______, RALT(KC_E),    _______,  _______, _______,
        _______, _______, _______,    _______, RALT(KC_C),    _______, _______,    _______,    MEH,     _______, _______, _______, _______,                 _______, _______,
        _______,          _______,    _______,                _______,             _______,             _______,          _______, _______,       _______,  _______, _______
    ),

    [4] = LAYOUT_all(
        RESET,            _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,       _______, _______, TG(1),
        _______,          _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,       _______, _______, _______,
        _______,          _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,       _______, _______, _______,
        _______, _______, _______,    _______, _______,       _______, _______,    _______,    _______, _______, _______, _______, _______,                _______, _______,
        _______,          _______,    _______,                _______,             _______,             _______,          _______, _______,       _______, _______, _______
    )
};

void eeconfig_init_user(void) {
  set_unicode_input_mode(UC_LNX);
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  switch (keycode) {
    case TABLE_FLIP:
      if (record->event.pressed) {
        /* send_unicode_string("(╯°益°)╯彡┻━┻"); */
        /* send_unicode_hex_string("28 256f b0 76ca b0 29 256f 5f61 253b 2501 253b"); */
        /* ("0x28 0xe2 0x95 0xaf 0xc2 0xb0 0xe7 0x9b 0x8a 0xc2 0xb0 0x29 0xe2 0x95 0xaf 0xe5 0xbd 0xa1 0xe2 0x94 0xbb 0xe2 0x94 0x81 0xe2 0x94 0xbb"); */
        send_unicode_hex_string("0028 256F 00B0 76CA 00B0 0029 256F 5F61 253B 2501 253B 000A");
      }
      break;
    case MEH:
      if (record->event.pressed) {
        send_unicode_string("¯\\_(ツ)_/¯");
      }
      break;
    case HUE:
      if (record->event.pressed) {
        send_string("HuEhUeHuE");
      }
      break;
  }
  return true;
};
