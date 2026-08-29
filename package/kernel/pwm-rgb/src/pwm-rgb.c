// SPDX-License-Identifier: GPL-2.0-only
/*
 * Xiaomi Multi-channel PWM RGB LED driver
 *
 * Direct control of front RGB LEDs via standard OpenWrt LED sysfs class.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/leds.h>
#include <linux/pwm.h>
#include <linux/workqueue.h>
#include <linux/slab.h>

#define MAX_COLORS 4

struct pwm_rgb_led {
	struct led_classdev cdev;
	struct work_struct work;
	u8 num_colors;
	u8 can_sleep;
	u32 color;
	u32 period;
	struct pwm_device **pwms;
};

struct pwm_rgb_priv {
	u8 num_leds;
	struct pwm_rgb_led leds[];
};

static void pwm_rgb_update(struct pwm_rgb_led *led)
{
	u8 colors[MAX_COLORS];
	int i;

	colors[0] = (led->color >> 24) & 0xff;
	colors[1] = (led->color >> 16) & 0xff;
	colors[2] = (led->color >> 8) & 0xff;
	colors[3] = led->color & 0xff;

	for (i = 0; i < led->num_colors; i++) {
		struct pwm_state state;
		u64 duty;

		if (!led->pwms[i])
			continue;

		duty = DIV_ROUND_CLOSEST_ULL((u64)led->period * colors[i], 255);

		pwm_get_state(led->pwms[i], &state);
		if (state.duty_cycle != duty || state.period != led->period) {
			state.period = led->period;
			state.duty_cycle = duty;
			pwm_apply_state(led->pwms[i], &state);
		}

		if (state.enabled != (duty > 0)) {
			state.enabled = (duty > 0);
			pwm_apply_state(led->pwms[i], &state);
		}
	}
}

static void pwm_rgb_work(struct work_struct *work)
{
	struct pwm_rgb_led *led = container_of(work, struct pwm_rgb_led, work);
	pwm_rgb_update(led);
}

static int pwm_rgb_set_blocking(struct led_classdev *ldev, enum led_brightness value)
{
	struct pwm_rgb_led *led = container_of(ldev, struct pwm_rgb_led, cdev);

	led->color = (u32)value;
	if (led->can_sleep)
		queue_work(system_wq, &led->work);
	else
		pwm_rgb_update(led);

	return 0;
}

static void pwm_rgb_cleanup(struct pwm_rgb_priv *priv)
{
	int i;

	for (i = priv->num_leds - 1; i >= 0; i--) {
		led_classdev_unregister(&priv->leds[i].cdev);
		if (priv->leds[i].can_sleep)
			cancel_work_sync(&priv->leds[i].work);
	}
}

static int pwm_rgb_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *node = dev->of_node;
	struct device_node *child, *color_node;
	struct pwm_rgb_priv *priv;
	int num_leds = 0;
	int led_idx = 0;

	if (!node)
		return -ENODEV;

	for_each_child_of_node(node, child)
		num_leds++;

	if (!num_leds)
		return -ENODEV;

	priv = devm_kzalloc(dev, sizeof(*priv) + num_leds * sizeof(struct pwm_rgb_led), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->num_leds = num_leds;

	for_each_child_of_node(node, child) {
		struct pwm_rgb_led *led = &priv->leds[led_idx];
		const char *label;
		u32 period = 50000;
		u32 brightness = 0;
		int num_colors = 0;
		int color_idx = 0;
		int ret;

		label = of_get_property(child, "label", NULL);
		if (!label)
			label = child->name;

		of_property_read_u32(child, "period", &period);
		of_property_read_u32(child, "brightness", &brightness);

		for_each_child_of_node(child, color_node)
			num_colors++;

		if (num_colors < 1 || num_colors > MAX_COLORS) {
			dev_err(dev, "invalid number of colors %d of pwm rgb led %s\n", num_colors, label);
			continue;
		}

		led->pwms = devm_kcalloc(dev, num_colors, sizeof(struct pwm_device *), GFP_KERNEL);
		if (!led->pwms) {
			dev_err(dev, "failed to allocate memory for pwm of %s\n", label);
			pwm_rgb_cleanup(priv);
			return -ENOMEM;
		}

		led->num_colors = num_colors;
		led->period = period;
		led->color = brightness;

		for_each_child_of_node(child, color_node) {
			struct pwm_device *pwm;

			pwm = devm_of_pwm_get(dev, color_node, NULL);
			if (IS_ERR(pwm)) {
				ret = PTR_ERR(pwm);
				dev_err(dev, "unable to request PWM for %s: %d\n", label, ret);
				pwm_rgb_cleanup(priv);
				return ret;
			}

			led->can_sleep = 1;
			led->pwms[color_idx++] = pwm;
		}

		INIT_WORK(&led->work, pwm_rgb_work);
		led->cdev.name = label;
		led->cdev.brightness_set_blocking = pwm_rgb_set_blocking;
		led->cdev.max_brightness = LED_FULL;
		led->cdev.brightness = brightness;

		ret = led_classdev_register_ext(dev, &led->cdev, NULL);
		if (ret) {
			dev_err(dev, "failed to register PWM RGB for %s: %d\n", label, ret);
			pwm_rgb_cleanup(priv);
			return ret;
		}

		pwm_rgb_update(led);
		led_idx++;
	}

	platform_set_drvdata(pdev, priv);
	return 0;
}

static int pwm_rgb_remove(struct platform_device *pdev)
{
	struct pwm_rgb_priv *priv = platform_get_drvdata(pdev);

	if (priv)
		pwm_rgb_cleanup(priv);

	return 0;
}

static const struct of_device_id of_pwm_rgb_match[] = {
	{ .compatible = "pwm-rgb", },
	{},
};
MODULE_DEVICE_TABLE(of, of_pwm_rgb_match);

static struct platform_driver pwm_rgb_driver = {
	.probe		= pwm_rgb_probe,
	.remove		= pwm_rgb_remove,
	.driver		= {
		.name	= "pwm-rgb",
		.of_match_table = of_pwm_rgb_match,
	},
};

module_platform_driver(pwm_rgb_driver);

MODULE_ALIAS("platform:pwm-rgb");
MODULE_DESCRIPTION("Xiaomi PWM RGB LED driver");
MODULE_LICENSE("GPL");
