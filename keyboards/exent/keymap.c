#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    /* layer 0: qwerty */
    [0] = LAYOUT_all(
        KC_GRV,               KC_1,    KC_2,     KC_3,     KC_4,    KC_5,            KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSLS, KC_ESC,  KC_HOME,
        KC_TAB,               KC_Q,    KC_W,     KC_E,     KC_R,    KC_T,            KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,          KC_PGUP,
        MT(MOD_LCTL, KC_ESC), KC_A,    KC_S,     KC_D,     KC_F,    KC_G,            KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, XXXXXXX, KC_ENT,           KC_PGDN,
        KC_LSFT, XXXXXXX,     KC_Z,    KC_X,     KC_C,     KC_V,    KC_B,            KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,          KC_UP,            KC_END,
        KC_LCTL,              KC_LALT, KC_LGUI,            XXXXXXX, LT(2, KC_SPC),   XXXXXXX,                   KC_RALT,  KC_RGUI, MO(3),   KC_LEFT, KC_DOWN,          KC_RGHT),

    [1] = LAYOUT_all(
        KC_GRV,               KC_1,    KC_2,     KC_3,     KC_4,    KC_5,            KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSLS, KC_ESC,  XXXXXXX,
        KC_TAB,               KC_Q,    KC_W,     KC_E,     KC_R,    KC_T,            KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,          KC_PGUP,
        KC_LCTL,              KC_A,    KC_S,     KC_D,     KC_F,    KC_G,            KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, XXXXXXX, KC_ENT,           KC_PGDN,
        KC_LSFT, XXXXXXX,     KC_Z,    KC_X,     KC_C,     KC_V,    KC_B,            KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,          KC_UP,            KC_END,
        KC_LCTL,              KC_LALT, KC_LGUI,            XXXXXXX, KC_SPC,          XXXXXXX,                   KC_RALT,  KC_RGUI, MO(3),   KC_LEFT, KC_DOWN,          KC_RGHT),

    [2] = LAYOUT_all(
        KC_GRV,               KC_F1,   KC_F2,    KC_F3,    KC_F4,   KC_F5,           KC_F6,   KC_F7,   KC_F8,   KC_F9,    KC_F10,  KC_F11,  KC_F12,  XXXXXXX, XXXXXXX, XXXXXXX,
        KC_TAB,               XXXXXXX, KC_UP,    XXXXXXX,  XXXXXXX, XXXXXXX,         XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  KC_P,    XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX,
        KC_LCTL,              KC_LEFT, KC_DOWN,  KC_RIGHT, XXXXXXX, XXXXXXX,         KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, XXXXXXX, XXXXXXX, XXXXXXX, KC_ENT,           KC_PGDN,
        KC_LSFT, XXXXXXX,     XXXXXXX, XXXXXXX,  XXXXXXX,  XXXXXXX, XXXXXXX,         XXXXXXX, XXXXXXX, KC_MPRV, KC_MNXT,  KC_MPLY, KC_RSFT,          KC_UP,            KC_END,
        KC_LCTL,              KC_LALT, KC_LGUI,            XXXXXXX, KC_SPC,          XXXXXXX,                   KC_RALT,  KC_RGUI, MO(3),   KC_LEFT, KC_DOWN,          KC_RGHT),

    [3] = LAYOUT_all(
        RESET,                XXXXXXX,  XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX,         XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, TG(1),
        BL_TOGG,              BL_STEP,  BL_INC,  BL_DEC,   RESET,   XXXXXXX,         XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX,
        RGB_TOG,              RGB_MOD,  RGB_HUI, RGB_SAI,  RGB_VAI, RGB_SPI,         XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX,
        XXXXXXX, XXXXXXX,     RGB_RMOD, RGB_HUD, RGB_SAD,  RGB_VAD, RGB_SPD,         XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX,          XXXXXXX,          XXXXXXX,
        XXXXXXX,              XXXXXXX,  XXXXXXX,           XXXXXXX, XXXXXXX,         XXXXXXX,                   XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX),
    };
