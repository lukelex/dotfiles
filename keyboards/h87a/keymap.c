#include QMK_KEYBOARD_H

enum kaomojies {
  LOVE = SAFE_RANGE,
  MEH,
  TABLE_FLIP,
};

enum unicode_names {
  // Danish
  lae,
  loe,
  laa,
  uae,
  uoe,
  uaa,
};

const uint32_t PROGMEM unicode_map[] = {
  // Danish
  [lae] = 0x00E6,
  [loe] = 0x00F8,
  [laa] = 0x00E5,
  [uae] = 0x00C6,
  [uoe] = 0x00D8,
  [uaa] = 0x00C5,
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_all(
    KC_ESC,                       KC_F1,   KC_F2,      KC_F3,   KC_F4,         KC_F5,      KC_F6,   KC_F7,   KC_F8,      KC_F9,   KC_F10,        KC_F11,  KC_F12,                  KC_MPRV, KC_MPLY, KC_MNXT,
    KC_GRV,           KC_1,       KC_2,    KC_3,       KC_4,    KC_5,          KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS,   KC_ESC,       KC_INS,  KC_HOME, KC_PGUP,
    KC_TAB,           KC_Q,       KC_W,    KC_E,       KC_R,    KC_T,          KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,                 KC_DEL,  KC_END,  KC_PGDN,
    LCTL(KC_ESC),     KC_A,       KC_S,    KC_D,       KC_F,    KC_G,          KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,       KC_NUHS, KC_ENT,
    KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,       KC_V,    KC_B,          KC_N,       KC_M,    KC_COMM, KC_DOT,     KC_SLSH, KC_RSFT,                XXXXXXX,                          KC_UP,
    KC_LALT,          XXXXXXX,    KC_LGUI,                      LT(2, KC_SPC),                                           XXXXXXX, MO(3),         XXXXXXX, MO(4),                   KC_LEFT, KC_DOWN, KC_RGHT),

  [1] = LAYOUT_all(
    KC_ESC,                       KC_F1,   KC_F2,      KC_F3,   KC_F4,         KC_F5,      KC_F6,   KC_F7,   KC_F8,      KC_F9,   KC_F10,        KC_F11,  KC_F12,                  KC_MPRV, KC_MPLY, KC_MNXT,
    KC_GRV,           KC_1,       KC_2,    KC_3,       KC_4,    KC_5,          KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS,   KC_ESC,       KC_INS,  KC_HOME, KC_PGUP,
    KC_TAB,           KC_Q,       KC_W,    KC_E,       KC_R,    KC_T,          KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC, KC_BSPC,                 KC_DEL,  KC_END,  KC_PGDN,
    KC_LCTL,          KC_A,       KC_S,    KC_D,       KC_F,    KC_G,          KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,       KC_NUHS, KC_ENT,
    KC_LSFT, XXXXXXX, KC_Z,       KC_X,    KC_C,       KC_V,    KC_B,          KC_N,       KC_M,    KC_COMM, KC_DOT,     KC_SLSH, KC_RSFT,                XXXXXXX,                          KC_UP,
    KC_LALT,          XXXXXXX,    KC_LGUI,                      KC_SPC,                                                  XXXXXXX, MO(3),         XXXXXXX, MO(4),                   KC_LEFT, KC_DOWN, KC_RGHT),

  [2] = LAYOUT_all(
    KC_ESC,                       XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    KC_GRV,           XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    KC_MUTE, KC_VOLD,       KC_VOLU, XXXXXXX,   XXXXXXX,      XXXXXXX, XXXXXXX, XXXXXXX,
    KC_TAB,           XXXXXXX,    KC_UP,   XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    KC_PSCR, XXXXXXX,       XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    MOD_LCTL,         KC_LEFT,    KC_DOWN, KC_RIGHT,   XXXXXXX, XXXXXXX,       KC_LEFT,    KC_DOWN, KC_UP,   KC_RIGHT,   XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,
    KC_LSFT, XXXXXXX, KC_MPRV,    KC_MNXT, KC_MPLY,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, KC_MPRV, KC_MNXT,    KC_MPLY, XXXXXXX,                XXXXXXX,                          KC_UP,
    KC_LALT,          XXXXXXX,    KC_LGUI,                      _______,                                                 XXXXXXX, KC_RALT,       XXXXXXX, XXXXXXX,                 KC_LEFT, KC_DOWN, KC_RGHT),

  [3] = LAYOUT_all(
    XXXXXXX,                      XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    RALT(KC_N),       XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       RALT(KC_I), XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, LGUI(KC_MINS), XXXXXXX, XXXXXXX,   XXXXXXX,      XXXXXXX, XXXXXXX, XXXXXXX,
    KC_TAB,           XXXXXXX,    XXXXXXX, RALT(KC_E), XXXXXXX, TABLE_FLIP,    XXXXXXX,    XXXXXXX, XXXXXXX, RALT(KC_O), XXXXXXX, XXXXXXX,       XXXXXXX, KC_DEL,                  XXXXXXX, XXXXXXX, XXXXXXX,
    MOD_LCTL,         RALT(KC_A), XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, LOVE,       XXXXXXX, RALT(KC_E),    XXXXXXX, XXXXXXX,
    KC_LSFT, XXXXXXX, XXXXXXX,    XXXXXXX, RALT(KC_C), XXXXXXX, XXXXXXX,       XXXXXXX,    MEH,     XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,                XXXXXXX,                          XXXXXXX,
    KC_LALT,          XXXXXXX,    XXXXXXX,                      XXXXXXX,                                                 XXXXXXX, _______,       XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX),

  [4] = LAYOUT_all(
    RESET,                        XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,          XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,   TG(1),        XXXXXXX, XXXXXXX, XXXXXXX,
    RGB_TOG,          RGB_HUI,    RGB_SAI, RGB_VAI,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    RGB_MOD,          RGB_HUD,    RGB_SAD, RGB_VAD,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX,
    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,                XXXXXXX,                          KC_MS_U,
    XXXXXXX,          XXXXXXX,    XXXXXXX,                      XXXXXXX,                                                 XXXXXXX, XXXXXXX,       XXXXXXX, _______,                 KC_MS_L, KC_MS_D, KC_MS_R),
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
  }
  return true;
};
