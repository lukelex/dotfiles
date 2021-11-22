#include QMK_KEYBOARD_H

enum kaomojies {
  MEH = SAFE_RANGE,
  TABLE_FLIP,
  HUE,
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_all(
    KC_ESC,                       KC_F1,   KC_F2,         KC_F3,   KC_F4,         KC_F5,      KC_F6,   KC_F7,   KC_F8,      KC_F9,   KC_F10,        KC_F11,  KC_F12,            KC_MPRV, KC_MPLY, KC_MNXT,
    KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,          KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS, KC_ESC,   KC_INS,  KC_HOME, KC_PGUP,
    KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,          KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,           KC_DEL,  KC_END,  KC_PGDN,
    LCTL_T(KC_ESC),   KC_A,       KC_S,    KC_D,          KC_F,    KC_G,          KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,       KC_NUHS, KC_ENT,
    KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,          KC_N,       KC_M,    KC_COMM, KC_DOT,     KC_SLSH, KC_RSFT,                MO(4),                    KC_UP,
    KC_LALT,          KC_LALT,    KC_LGUI,                         LT(2, KC_SPC),                                           XXXXXXX, MO(3),         KC_RALT, MO(4),             KC_LEFT, KC_DOWN, KC_RGHT),

  [1] = LAYOUT_all(
    KC_ESC,                       KC_F1,   KC_F2,         KC_F3,   KC_F4,         KC_F5,      KC_F6,   KC_F7,   KC_F8,      KC_F9,   KC_F10,        KC_F11,  KC_F12,            KC_MPRV, KC_MPLY, KC_MNXT,
    KC_GRV,           KC_1,       KC_2,    KC_3,          KC_4,    KC_5,          KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS, KC_ESC,   KC_INS,  KC_HOME, KC_PGUP,
    KC_TAB,           KC_Q,       KC_W,    KC_E,          KC_R,    KC_T,          KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,           KC_DEL,  KC_END,  KC_PGDN,
    KC_LCTL,          KC_A,       KC_S,    KC_D,          KC_F,    KC_G,          KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,       KC_NUHS, KC_ENT,
    KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,          KC_V,    KC_B,          KC_N,       KC_M,    KC_COMM, KC_DOT,     KC_SLSH, KC_RSFT,                MO(4),                    KC_UP,
    KC_LALT,          _______,    KC_LGUI,                         KC_SPC,                                                  _______, MO(3),         _______, MO(4),             KC_LEFT, KC_DOWN, KC_RGHT),

  [2] = LAYOUT_all(
    _______,                      _______, _______,       _______, _______,       _______,    _______, _______, _______,    _______, _______,       _______, _______,           _______, _______, _______,
    _______,          _______,    _______, _______,       _______, _______,       _______,    _______, _______, _______,    KC_MUTE, KC_VOLD,       KC_VOLU, _______,  _______, _______, _______, _______,
    _______,          _______,    KC_UP,   _______,       _______, _______,       _______,    _______, _______, _______,    KC_PSCR, _______,       _______, KC_DEL,            _______, _______, _______,
    KC_LCTL,          KC_LEFT,    KC_DOWN, KC_RIGHT,      _______, _______,       KC_LEFT,    KC_DOWN, KC_UP,   KC_RIGHT,   _______, _______,       _______, _______,
    _______, _______, _______,    _______, _______,       _______, _______,       _______,    _______, KC_MPRV, KC_MNXT,    KC_MPLY, _______,                _______,                    _______,
    _______,          _______,    _______,                         _______,                                                 _______, _______,       _______, _______,           _______, _______, _______),

  [3] = LAYOUT_all(
    _______,                      _______, _______,       _______, _______,       _______,    _______, _______, _______,    _______, _______,       _______, _______,           _______, _______, _______,
    RALT(KC_N),       _______,    _______, _______,       _______, _______,       RALT(KC_I), _______, _______, _______,    _______, LGUI(KC_MINS), _______, _______,  _______, _______, _______, _______,
    _______,          _______,    _______, RALT(KC_QUOT), _______, TABLE_FLIP,    _______,    _______, _______, RALT(KC_O), _______, _______,       _______, _______,           _______, _______, _______,
    _______,          RALT(KC_A), _______, _______,       _______, _______,       HUE,        _______, _______, _______,    _______, RALT(KC_E),    _______, _______,
    _______, _______, _______,    _______, RALT(KC_C),    _______, _______,       _______,    MEH,     _______, _______,    _______, _______,                _______,                    _______,
    _______,          _______,    _______,                         _______,                                                 _______, _______,       _______, _______,           _______, _______, _______),

  [4] = LAYOUT_all(
    RESET,                        XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,           XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,  TG(1),   XXXXXXX, XXXXXXX, XXXXXXX,
    RGB_TOG,          RGB_HUI,    RGB_SAI, RGB_VAI,       XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,           XXXXXXX, XXXXXXX, XXXXXXX,
    RGB_MOD,          RGB_HUD,    RGB_SAD, RGB_VAD,       XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,
    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,                XXXXXXX,                    KC_MS_U,
    XXXXXXX,          XXXXXXX,    XXXXXXX,                         XXXXXXX,                                                 XXXXXXX, XXXXXXX,       XXXXXXX, _______,           KC_MS_L, KC_MS_D, KC_MS_R),
};

void eeconfig_init_user(void) {
  set_unicode_input_mode(UC_LNX);
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  switch (keycode) {
    case TABLE_FLIP:
      if (record->event.pressed) {
        send_unicode_string("(╯°益°)╯彡┻━┻");
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
