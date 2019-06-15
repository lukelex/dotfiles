#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
[0] = LAYOUT(
    KC_GRV,               KC_1,    KC_2,    KC_3,    KC_4,             KC_5,    KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  XXXXXXX, KC_BSLS,
    KC_TAB,               KC_Q,    KC_W,    KC_E,    KC_R,             KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,
    MT(MOD_LCTL, KC_ESC), KC_A,    KC_S,    KC_D,    KC_F,             KC_G,    KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_ENT,
    KC_LSFT,XXXXXXX,      KC_Z,    KC_X,    KC_C,    KC_V,             KC_B,    KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT, MO(1),
		XXXXXXX,              KC_LALT, KC_LGUI, KC_SPC,  LT(1, KC_SPACE),  XXXXXXX, XXXXXXX, DF(2),   XXXXXXX, MO(1),    XXXXXXX),

[1] = LAYOUT(
    XXXXXXX,              KC_F1,   KC_F2,   KC_F3,   KC_F4,            KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,    KC_F10,  KC_F11,  KC_F12,  XXXXXXX, XXXXXXX,
    KC_TAB,               KC_MPRV, KC_MPLY, KC_MNXT, XXXXXXX,          XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
    KC_LCTL,              XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX, KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, XXXXXXX, XXXXXXX, XXXXXXX,
		KC_LSFT,XXXXXXX,      XXXXXXX, XXXXXXX, BL_DEC,  BL_TOGG,          BL_INC,  BL_STEP, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
		XXXXXXX,              KC_LALT, KC_LGUI, KC_SPC, XXXXXXX,           XXXXXXX, XXXXXXX, DF(0),   XXXXXXX, MO(3),    XXXXXXX),

[2] = LAYOUT(
	  KC_GRV,               KC_1,    KC_2,    KC_3,    KC_4,             KC_5,    KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  XXXXXXX, KC_BSLS,
    KC_TAB,               KC_Q,    KC_W,    KC_E,    KC_R,             KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,
    KC_LCTL,              KC_A,    KC_S,    KC_D,    KC_F,             KC_G,    KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_ENT,
    KC_LSFT,XXXXXXX,      KC_Z,    KC_X,    KC_C,    KC_V,             KC_B,    KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT, MO(1),
		XXXXXXX,              KC_LALT, KC_LGUI, KC_SPC,  KC_SPACE,         XXXXXXX, XXXXXXX, DF(0),   XXXXXXX, MO(1),    XXXXXXX),

[3] = LAYOUT(
    RESET,                XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
		XXXXXXX,              RGB_TOG, RGB_MOD, RGB_HUI, RGB_HUD,          RGB_SAI, RGB_SAD, RGB_VAI, RGB_VAD, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,XXXXXXX,      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
		XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,          XXXXXXX, XXXXXXX, DF(0),   XXXXXXX, XXXXXXX,  XXXXXXX),
};
