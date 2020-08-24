#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_default(
      KC_ESC,  KC_TAB,               KC_Q,    KC_W,    KC_E,       KC_R,    KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,
      XXXXXXX, MT(MOD_LCTL, KC_ESC), KC_A,    KC_S,    KC_D,       KC_F,    KC_G,    KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_ENT,
      XXXXXXX, KC_LSFT, XXXXXXX,     KC_Z,    KC_X,    KC_C,       KC_V,    KC_B,    KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,          MO(5),
      XXXXXXX,                       KC_LALT, KC_LGUI, KC_SPC,                       LT(2, KC_ENT),    MO(4),   MO(3)
      ),

  [1] = LAYOUT_default(
      KC_ESC,  KC_TAB,               KC_Q,    KC_W,    KC_E,       KC_R,    KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,
      KC_PGUP, KC_LCTL,              KC_A,    KC_S,    KC_D,       KC_F,    KC_G,    KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_ENT,
      KC_PGDN, KC_LSFT, XXXXXXX,     KC_Z,    KC_X,    KC_C,       KC_V,    KC_B,    KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,          MO(5),
      XXXXXXX,                       KC_LALT, KC_LGUI, KC_SPC,                       LT(2, KC_ENT),    MO(4),   MO(3)
      ),

  [2] = LAYOUT_default(
      KC_ESC,  KC_GRV,               KC_1,    KC_2,    KC_3,       KC_4,    KC_5,    KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSLS,
      XXXXXXX, KC_LCTL,              XXXXXXX, XXXXXXX,   XXXXXXX,    XXXXXXX, XXXXXXX, KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, XXXXXXX, XXXXXXX, XXXXXXX,
      XXXXXXX, KC_LSFT, XXXXXXX,     XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_MPRV, KC_MNXT,  KC_MPLY, XXXXXXX,          XXXXXXX,
      XXXXXXX,                       KC_LALT, KC_LGUI, KC_SPC,                       _______,          XXXXXXX, XXXXXXX
      ),

  [3] = LAYOUT_default(
      KC_ESC,  XXXXXXX,              KC_F1,   KC_F2,   KC_F3,      KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,    KC_F10,  KC_F11,  KC_F12,  XXXXXXX,
      XXXXXXX, XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
      XXXXXXX, KC_LSFT, XXXXXXX,     XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX,          XXXXXXX,
      XXXXXXX,                       XXXXXXX, XXXXXXX, XXXXXXX,                      XXXXXXX,          XXXXXXX, XXXXXXX
      ),

  [4] = LAYOUT_default(
      KC_ESC,  RALT(KC_N),           XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, RALT(KC_I), XXXXXXX, XXXXXXX, XXXXXXX,  KC_PSCR, XXXXXXX, XXXXXXX, LGUI(KC_MINS),
      XXXXXXX, XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, RALT(KC_E), XXXXXXX,
      XXXXXXX, KC_LSFT, XXXXXXX,     XXXXXXX, XXXXXXX, RALT(KC_C), XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX,          XXXXXXX,
      XXXXXXX,                       XXXXXXX, XXXXXXX, XXXXXXX,                      XXXXXXX,          XXXXXXX, XXXXXXX
      ),

  [5] = LAYOUT_default(
      RESET,   XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, TG(1),
      BL_TOGG, XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
      BL_INC,  XXXXXXX, XXXXXXX,     XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          _______,
      BL_DEC,                        XXXXXXX, XXXXXXX, XXXXXXX,                      XXXXXXX,          XXXXXXX, XXXXXXX
      )
};
