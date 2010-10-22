/*
 * (C) Copyright 2009
 * Marvell Semiconductor <www.marvell.com>
 * Written-by: Prafulla Wadaskar <prafulla@marvell.com>
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301 USA
 */

#include <common.h>
#include <miiphy.h>
#include <asm/arch/kirkwood.h>
#include <asm/arch/mpp.h>
#include <linux/ctype.h> /* isspace */
#include <status_led.h>
#include "dockstar.h"

DECLARE_GLOBAL_DATA_PTR;

int board_init(void)
{
	/*
	 * default gpio configuration
	 * There are maximum 64 gpios controlled through 2 sets of registers
	 * the  below configuration configures mainly initial LED status
	 */
	kw_config_gpio(DOCKSTAR_OE_VAL_LOW,
			DOCKSTAR_OE_VAL_HIGH,
			DOCKSTAR_OE_LOW, DOCKSTAR_OE_HIGH);

	/* Multi-Purpose Pins Functionality configuration */
	u32 kwmpp_config[] = {
		MPP0_NF_IO2,
		MPP1_NF_IO3,
		MPP2_NF_IO4,
		MPP3_NF_IO5,
		MPP4_NF_IO6,
		MPP5_NF_IO7,
		MPP6_SYSRST_OUTn,
		MPP7_GPO,
		MPP8_UART0_RTS,
		MPP9_UART0_CTS,
		MPP10_UART0_TXD,
		MPP11_UART0_RXD,
		MPP12_SD_CLK,
		MPP13_SD_CMD,
		MPP14_SD_D0,
		MPP15_SD_D1,
		MPP16_SD_D2,
		MPP17_SD_D3,
		MPP18_NF_IO0,
		MPP19_NF_IO1,
		MPP20_GPIO,
		MPP21_GPIO,
		MPP22_GPIO,
		MPP23_GPIO,
		MPP24_GPIO,
		MPP25_GPIO,
		MPP26_GPIO,
		MPP27_GPIO,
		MPP28_GPIO,
		MPP29_TSMP9,
		MPP30_GPIO,
		MPP31_GPIO,
		MPP32_GPIO,
		MPP33_GPIO,
		MPP34_GPIO,
		MPP35_GPIO,
		MPP36_GPIO,
		MPP37_GPIO,
		MPP38_GPIO,
		MPP39_GPIO,
		MPP40_GPIO,
		MPP41_GPIO,
		MPP42_GPIO,
		MPP43_GPIO,
		MPP44_GPIO,
		MPP45_GPIO,
		MPP46_GPIO,
		MPP47_GPIO,
		MPP48_GPIO,
		MPP49_GPIO,
		0
	};
	kirkwood_mpp_conf(kwmpp_config);

	/* adress of boot parameters */
	gd->bd->bi_boot_params = kw_sdram_bar(0) + 0x100;

return 0;
}

int misc_init_r()
{
  int __machine_arch_type;
  char *str_arc_number = getenv("arcNumber");

  if (str_arc_number) {
    __machine_arch_type = simple_strtoul(str_arc_number, NULL, 10);
    if (!__machine_arch_type)
      __machine_arch_type = MACH_TYPE_DOCKSTAR;
  }

	/*
	 * arch number of board
	 */
	gd->bd->bi_arch_number = __machine_arch_type;
}

int dram_init(void)
{
	int i;

	for (i = 0; i < CONFIG_NR_DRAM_BANKS; i++) {
		gd->bd->bi_dram[i].start = kw_sdram_bar(i);
		gd->bd->bi_dram[i].size = kw_sdram_bs(i);
	}
	return 0;
}

#ifdef CONFIG_RESET_PHY_R
/* Configure and enable MV88E1116 PHY */
void reset_phy(void)
{
	u16 reg;
	u16 devadr;
	char *name = "egiga0";

	if (miiphy_set_current_dev(name))
		return;

	/* command to read PHY dev address */
	if (miiphy_read(name, 0xEE, 0xEE, (u16 *) &devadr)) {
		printf("Err..%s could not read PHY dev address\n",
			__FUNCTION__);
		return;
	}

	/*
	 * Enable RGMII delay on Tx and Rx for CPU port
	 * Ref: sec 4.7.2 of chip datasheet
	 */
	miiphy_write(name, devadr, MV88E1116_PGADR_REG, 2);
	miiphy_read(name, devadr, MV88E1116_MAC_CTRL_REG, &reg);
	reg |= (MV88E1116_RGMII_RXTM_CTRL | MV88E1116_RGMII_TXTM_CTRL);
	miiphy_write(name, devadr, MV88E1116_MAC_CTRL_REG, reg);
	miiphy_write(name, devadr, MV88E1116_PGADR_REG, 0);

	/* reset the phy */
	miiphy_reset(name, devadr);

	printf("88E1116 Initialized on %s\n", name);
}
#endif /* CONFIG_RESET_PHY_R */


static uint8_t saved_state[2] = {STATUS_LED_OFF, STATUS_LED_OFF};
static uint8_t saved_blink_state[2] = {STATUS_LED_OFF, STATUS_LED_OFF};
static uint32_t gpio_pin[2] = {1 << (14 + STATUS_LED_GREEN),
			       1 << (14 + STATUS_LED_RED)};

inline void switch_LED_on(uint8_t led)
{
  struct kwgpio_registers *gpio = (struct kwgpio_registers *)KW_GPIO1_BASE;

	writel(readl(&gpio->oe) & ~gpio_pin[led], &gpio->oe);
	saved_state[led] = STATUS_LED_ON;
}

inline void switch_LED_off(uint8_t led)
{
  struct kwgpio_registers *gpio = (struct kwgpio_registers *)KW_GPIO1_BASE;

	writel(readl(&gpio->oe) | gpio_pin[led], &gpio->oe);
	saved_state[led] = STATUS_LED_OFF;
}

void red_LED_on(void)
{
	switch_LED_on(STATUS_LED_RED);
}

void red_LED_off(void)
{
	switch_LED_off(STATUS_LED_RED);
}

void green_LED_on(void)
{
	switch_LED_on(STATUS_LED_GREEN);
}

void green_LED_off(void)
{
	switch_LED_off(STATUS_LED_GREEN);
}

void __led_init(led_id_t mask, int state)
{
	__led_set(mask, state);
}

void __led_toggle(led_id_t mask)
{
	if (STATUS_LED_RED == mask) {
		(saved_state[STATUS_LED_RED] == STATUS_LED_ON) ? red_LED_off() : red_LED_on();
	} else if (STATUS_LED_GREEN == mask) {
		(saved_state[STATUS_LED_GREEN] == STATUS_LED_ON) ? green_LED_off() : green_LED_on();
	}
}

void __led_set(led_id_t mask, int state)
{
	if (STATUS_LED_RED == mask) {
		(STATUS_LED_ON == state) ? red_LED_on() : red_LED_off();
	} else if (STATUS_LED_GREEN == mask) {
		(STATUS_LED_ON == state) ? green_LED_on() : green_LED_off();
	}
}

inline void switch_LED_blink_on(uint8_t led)
{
  struct kwgpio_registers *gpio = (struct kwgpio_registers *)KW_GPIO1_BASE;

	writel(readl(&gpio->blink_en) | gpio_pin[led], &gpio->blink_en);
	saved_state[led] = STATUS_LED_ON;
}

inline void switch_LED_blink_off(uint8_t led)
{
  struct kwgpio_registers *gpio = (struct kwgpio_registers *)KW_GPIO1_BASE;

	writel(readl(&gpio->blink_en) & ~gpio_pin[led], &gpio->blink_en);
	saved_state[led] = STATUS_LED_OFF;
}

void red_LED_blink_on(void)
{
	switch_LED_blink_on(STATUS_LED_RED);
}

void red_LED_blink_off(void)
{
	switch_LED_blink_off(STATUS_LED_RED);
}

void green_LED_blink_on(void)
{
	switch_LED_blink_on(STATUS_LED_GREEN);
}

void green_LED_blink_off(void)
{
	switch_LED_blink_off(STATUS_LED_GREEN);
}

void set_LED(char *szStatus)
{
  uint8_t led    = -1;
  uint8_t status = -1;

  /* Convert string to lowercase, max len 32 */
  int max = 32;
  char *s = szStatus;
  while (*s && max--)
    *s++ = tolower(*s);
  s = szStatus;

  /* Start with everything off */
  switch_LED_off(STATUS_LED_GREEN);
  switch_LED_blink_off(STATUS_LED_GREEN);
  switch_LED_off(STATUS_LED_RED);
  switch_LED_blink_off(STATUS_LED_RED);

  if (szStatus == NULL) 
  {
    red_LED_on();
    red_LED_blink_on();
    return;
  }

  if ( strncmp(s, "green", 5) == 0 )
  {
    s += 5;
    led = STATUS_LED_GREEN;
  }
  else if ( strncmp(s, "orange", 6) == 0 ) 
  {
    s += 6;
    led = STATUS_LED_RED;
  }
  else if ( strncmp(s, "red", 3) == 0 ) 
  {
    s += 3;
    led = STATUS_LED_RED;
  }

  if (led == -1 ) return;

  /* Skip Whitespace */
  while ( isspace(*s) ) s++;

  /* Commands like "green" or "orange" should just turn the light on */
  if ( *s == NULL || ( strncmp(s, "on", 2) == 0 ) )
    status = STATUS_LED_ON;
  else if ( strncmp(s, "blink", 5) == 0 )
    status = STATUS_LED_BLINKING;
  /* Unknown commands should turn the light off */
  else
    status = STATUS_LED_OFF;

  if (status == STATUS_LED_OFF)
  {
    switch_LED_off(led);
    switch_LED_blink_off(led);
  }
  else
  {
    switch_LED_on(led);
    if (status == STATUS_LED_BLINKING)
      switch_LED_blink_on(led);
  }
}


void show_boot_progress (int val)
{
  if (val < 0)
    set_LED( getenv("led_error") );

  /* Ethernet Init */
  else if (val == 64)
    set_LED( getenv("led_init") );

  /* Passing control to an image */
  else if (val == 15)
    set_LED( getenv("led_exit") );
}

