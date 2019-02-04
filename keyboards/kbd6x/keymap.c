#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
[0] = LAYOUT(
    KC_GRV,               KC_1,    KC_2,    KC_3,    KC_4,    KC_5,     KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSLS, KC_ESC,
    KC_TAB,               KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,     KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,
    MT(MOD_LCTL, KC_ESC), KC_A,    KC_S,    KC_D,    KC_F,    KC_G,     KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_ENT,
    KC_LSFT,              KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,     KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT, MO(1),
    XXXXXXX,              KC_LALT, KC_LGUI,                   LT(1, KC_SPACE),            DF(2),   KC_RALT,  XXXXXXX
    ),

[1] = LAYOUT(
    XXXXXXX,              KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,    KC_F6,   KC_F7,   KC_F8,   KC_F9,    KC_F10,  KC_F11,  KC_F12,  KC_MNXT, KC_MPLY,
    XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  KC_PSCR, XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              KC_VOLD, KC_MUTE, KC_VOLU, XXXXXXX, XXXXXXX,  KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              XXXXXXX, XXXXXXX,                   XXXXXXX,                    XXXXXXX, MO(3),    XXXXXXX
    ),

[2] = LAYOUT(
    KC_GRV,               KC_1,    KC_2,    KC_3,    KC_4,    KC_5,     KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSLS, KC_ESC,
    KC_TAB,               KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,     KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,
    KC_LCTL,              KC_A,    KC_S,    KC_D,    KC_F,    KC_G,     KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_ENT,
    KC_LSFT,              KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,     KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT, MO(1),
    _______,              KC_LALT, KC_LGUI,                   KC_SPACE,                   DF(0),   KC_RALT,  _______
    ),

[3] = LAYOUT(
    RESET  ,              _______, _______, _______, _______, _______,  _______, _______, _______, _______,  _______, _______, _______, _______, _______,
    _______,              _______, _______, _______, _______, _______,  _______, _______, _______, _______,  _______, _______, _______, _______,
    _______,              _______, _______, _______, _______, _______,  _______, _______, _______, _______,  _______, _______, _______,
    _______,              _______, _______, _______, _______, _______,  _______, _______, _______, _______,  _______, _______, _______,
    _______,              _______, _______,                   _______,                    DF(0),   _______,  _______
    ),
};



void matrix_init_user(void) {

}

void matrix_scan_user(void) {

}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  return true;
}

