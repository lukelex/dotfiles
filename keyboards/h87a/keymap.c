/* Copyright 2018 Josh Hinnebusch

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include QMK_KEYBOARD_H

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {

  [0] = LAYOUT_all(
    KC_ESC,                        KC_F1,   KC_F2,    KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,    KC_F9,   KC_F10,  KC_F11,  KC_F12,                  KC_MPRV, KC_MPLY, KC_MNXT,
    KC_GRV,               KC_1,    KC_2,    KC_3,     KC_4,    KC_5,    KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSLS,   KC_ESC,       KC_INS,  KC_HOME, KC_PGUP,
    KC_TAB,               KC_Q,    KC_W,    KC_E,     KC_R,    KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSPC,                 KC_DEL,  KC_END,  KC_PGDN,
    MT(MOD_LCTL, KC_ESC), KC_A,    KC_S,    KC_D,     KC_F,    KC_G,    KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_NUHS, KC_ENT,
    KC_LSFT, XXXXXXX,     KC_Z,    KC_X,    KC_C,     KC_V,    KC_B,    KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,          XXXXXXX,                          KC_UP,
    KC_LALT,              XXXXXXX, KC_LGUI,                    LT(2, KC_SPC),                                XXXXXXX, KC_RALT, XXXXXXX, MO(3),                   KC_LEFT, KC_DOWN, KC_RGHT),

  [1] = LAYOUT_all(
    KC_ESC,                        KC_F1,   KC_F2,    KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,    KC_F9,   KC_F10,  KC_F11,  KC_F12,                  KC_MPRV, KC_MPLY, KC_MNXT,
    KC_GRV,               KC_1,    KC_2,    KC_3,     KC_4,    KC_5,    KC_6,    KC_7,    KC_8,    KC_9,     KC_0,    KC_MINS, KC_EQL,  KC_BSPC,   KC_ESC,       KC_INS,  KC_HOME, KC_PGUP,
    KC_TAB,               KC_Q,    KC_W,    KC_E,     KC_R,    KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,     KC_P,    KC_LBRC, KC_RBRC, KC_BSLS,                 KC_DEL,  KC_END,  KC_PGDN,
    KC_LCTL,              KC_A,    KC_S,    KC_D,     KC_F,    KC_G,    KC_H,    KC_J,    KC_K,    KC_L,     KC_SCLN, KC_QUOT, KC_NUHS, KC_ENT,
    KC_LSFT, XXXXXXX,     KC_Z,    KC_X,    KC_C,     KC_V,    KC_B,    KC_N,    KC_M,    KC_COMM, KC_DOT,   KC_SLSH, KC_RSFT,          XXXXXXX,                          KC_UP,
    KC_LCTL,              XXXXXXX, KC_LGUI,                    KC_SPC,                                       XXXXXXX, KC_RALT, XXXXXXX, MO(3),                   KC_LEFT, KC_DOWN, KC_RGHT),

  [2] = LAYOUT_all(
    KC_ESC,                        XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    KC_GRV,               XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX,      XXXXXXX, XXXXXXX, XXXXXXX,
    KC_TAB,               XXXXXXX, KC_UP,   XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    MOD_LCTL,             KC_LEFT, KC_DOWN, KC_RIGHT, XXXXXXX, XXXXXXX, KC_LEFT, KC_DOWN, KC_UP,   KC_RIGHT, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
    KC_LSFT, XXXXXXX,     XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, KC_MPRV, KC_MNXT,  KC_MPLY, XXXXXXX,          XXXXXXX,                          KC_UP,
    KC_LCTL,              KC_LGUI, KC_LALT,                    KC_SPC,                                       XXXXXXX, KC_RALT, XXXXXXX, MO(3),                   KC_LEFT, KC_DOWN, KC_RGHT),

  [3] = LAYOUT_all(
    RESET,                         XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, RGB_TOG, RGB_MOD, RGB_HUD, RGB_HUI,  RGB_SAD, RGB_SAI, RGB_VAD, RGB_VAI,                 BL_DEC,  BL_TOGG, BL_INC,
    XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   TG(1),        XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX, XXXXXXX,     XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,  XXXXXXX, XXXXXXX,          XXXXXXX,                          XXXXXXX,
    XXXXXXX,              XXXXXXX, XXXXXXX,                    XXXXXXX,                                      XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,                 XXXXXXX, XXXXXXX, XXXXXXX),

};

void matrix_init_user(void) {

}

void matrix_scan_user(void) {

}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  return true;
}

void led_init_ports(void) {
  DDRD |= (1<<5); // OUT
  DDRE |= (1<<6); // OUT
}

void led_set_user(uint8_t usb_led) {

  if (usb_led & (1 << USB_LED_CAPS_LOCK)) {
    DDRD |= (1 << 5); PORTD &= ~(1 << 5);
  } else {
    DDRD &= ~(1 << 5); PORTD &= ~(1 << 5);
  }

  if (usb_led & (1 << USB_LED_SCROLL_LOCK)) {
    DDRE |= (1 << 6); PORTE &= ~(1 << 6);
  } else {
    DDRE &= ~(1 << 6); PORTE &= ~(1 << 6);
  }

}