/* Copyright 2019 Ryota Goto
 *
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

enum layer_names {
    _BASE,
    _GAMING,
    _FN,
    _SHORTCUTS,
    _FIRMWARE
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [_BASE] = LAYOUT_all(
    KC_GRV,               KC_1,       KC_2,    KC_3,       KC_4,    KC_5,    KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS, KC_ESC,
    KC_TAB,               KC_Q,       KC_W,    KC_E,       KC_R,    KC_T,    KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC,          KC_BSPC,
    MT(MOD_LCTL, KC_ESC), KC_A,       KC_S,    KC_D,       KC_F,    KC_G,    KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,                         KC_ENT,
    KC_LSFT, XXXXXXX,     KC_Z,       KC_X,    KC_C,       KC_V,    KC_B,    KC_N,       KC_M,    KC_COMM, KC_DOT,     KC_SLSH,                         KC_RSFT, MO(4),
    KC_LALT, XXXXXXX,     KC_LGUI,             XXXXXXX,             LT(2, KC_SPC),       XXXXXXX,                      MO(3),   MO(3),         XXXXXXX, MO(4)),

  [_GAMING] = LAYOUT_all(
    KC_GRV,               KC_1,       KC_2,    KC_3,       KC_4,    KC_5,    KC_6,       KC_7,    KC_8,    KC_9,       KC_0,    KC_MINS,       KC_EQL,  KC_BSLS, KC_ESC,
    KC_TAB,               KC_Q,       KC_W,    KC_E,       KC_R,    KC_T,    KC_Y,       KC_U,    KC_I,    KC_O,       KC_P,    KC_LBRC,       KC_RBRC,          KC_BSPC,
    KC_LCTL,              KC_A,       KC_S,    KC_D,       KC_F,    KC_G,    KC_H,       KC_J,    KC_K,    KC_L,       KC_SCLN, KC_QUOT,                         KC_ENT,
    KC_LSFT, XXXXXXX,     KC_Z,       KC_X,    KC_C,       KC_V,    KC_B,    KC_N,       KC_M,    KC_COMM, KC_DOT,     KC_SLSH,                         KC_RSFT, MO(4),
    KC_LALT, XXXXXXX,     KC_LGUI,             XXXXXXX,             KC_SPC,              XXXXXXX,                      MO(3),   MO(3),         XXXXXXX, MO(4)),

  [_FN] = LAYOUT_all(
    KC_GRV,               KC_F1,      KC_F2,   KC_F3,      KC_F4,   KC_F5,   KC_F6,      KC_F7,   KC_F8,   KC_F9,      KC_F10,  KC_F11,        KC_F12,  KC_BSPC, KC_ESC,
    KC_TAB,               XXXXXXX,    KC_UP,   XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    KC_PSCR, KC_VOLD,       KC_VOLU,          KC_DEL,
    KC_LCTL,              KC_LEFT,    KC_DOWN, KC_RGHT,    XXXXXXX, XXXXXXX, KC_LEFT,    KC_DOWN, KC_UP,   KC_RGHT,    XXXXXXX, XXXXXXX,                         XXXXXXX,
    KC_LSFT, XXXXXXX,     XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    KC_MUTE, KC_MPRV, KC_MNXT,    KC_MPLY,                         XXXXXXX, XXXXXXX,
    KC_LALT, XXXXXXX,     KC_LGUI,             XXXXXXX,             _______,             XXXXXXX,                      XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX),

  [_SHORTCUTS] = LAYOUT_all(
    RALT(KC_N),           XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, RALT(KC_I), XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, LGUI(KC_MINS), XXXXXXX, XXXXXXX, XXXXXXX,
    XXXXXXX,              XXXXXXX,    XXXXXXX, RALT(KC_E), XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, RALT(KC_O), XXXXXXX, XXXXXXX,       XXXXXXX,          XXXXXXX,
    XXXXXXX,              RALT(KC_A), XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, RALT(KC_E),                         XXXXXXX,
    KC_LSFT, XXXXXXX,     XXXXXXX,    XXXXXXX, RALT(KC_C), XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,                         XXXXXXX, XXXXXXX,
    KC_LALT, XXXXXXX,     XXXXXXX,             XXXXXXX,             XXXXXXX,             XXXXXXX,                      _______, _______,       XXXXXXX, XXXXXXX),

  [_FIRMWARE] = LAYOUT_all(
    RESET,                XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX, XXXXXXX, TG(1),
    RGB_TOG,              RGB_HUI,    RGB_SAI, RGB_VAI,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,       XXXXXXX,          XXXXXXX,
    RGB_MOD,              RGB_HUD,    RGB_SAD, RGB_VAD,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX,                         XXXXXXX,
    XXXXXXX, XXXXXXX,     XXXXXXX,    XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX, XXXXXXX, XXXXXXX,    XXXXXXX,                         XXXXXXX, _______,
    XXXXXXX, XXXXXXX,     XXXXXXX,             XXXXXXX,             XXXXXXX,             XXXXXXX,                      XXXXXXX, XXXXXXX,       XXXXXXX, _______),
};
