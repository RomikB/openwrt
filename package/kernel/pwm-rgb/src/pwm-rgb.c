// SPDX-License-Identifier: GPL-2.0-only
/*
 * Xiaomi Multi-channel PWM Status LED driver for OpenWrt (RD15 / IPQ5332)
 *
 * Exposes each hardware PWM channel as a standard Linux LED class device
 * (e.g., blue:status, orange:status) with standard 0..255 brightness.
 * Fully compatible with OpenWrt LED subsystem, LuCI and /etc/diag.sh.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/leds.h>
#include <linux/pwm.h>
#include <linux/slab.h>

#define DEFAULT_PWM_PERIOD 50000 /* 50 us -> 20 kHz */

struct pwm_channel_led {
	struct led_classdev cdev;
	struct pwm_device *pwm;
	u32 period;
	char name[32];
};

struct pwm_rgb_priv {
	int num_leds;
	struct pwm_channel_led leds[];
};

static int pwm_channel_set_blocking(struct led_classdev *ldev, enum led_brightness value)
{
	struct pwm_channel_led *led = container_of(ldev, struct pwm_channel_led, cdev);
	struct pwm_state state;
	u64 duty;

	if (!led->pwm)
		return 0;

	duty = DIV_ROUND_CLOSEST_ULL((u64)led->period * value, 255);

	pwm_get_state(led->pwm, &state);
	state.period = led->period;
	state.duty_cycle = duty;
	state.enabled = (duty > 0);

	return pwm_apply_state(led->pwm, &state);
}

static void pwm_rgb_cleanup(struct pwm_rgb_priv *priv)
{
	int i;

	for (i = priv->num_leds - 1; i >= 0; i--) {
		if (priv->leds[i].cdev.dev)
			led_classdev_unregister(&priv->leds[i].cdev);

		if (priv->leds[i].pwm) {
			struct pwm_state state;
			pwm_get_state(priv->leds[i].pwm, &state);
			state.enabled = false;
			state.duty_cycle = 0;
			pwm_apply_state(priv->leds[i].pwm, &state);
		}
	}
}

static int pwm_rgb_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *node = dev->of_node;
	struct device_node *child, *channel_node;
	struct pwm_rgb_priv *priv;
	int total_leds = 0;
	int idx = 0;

	if (!node)
		return -ENODEV;

	/* Count channel nodes */
	for_each_child_of_node(node, child) {
		int sub_count = of_get_child_count(child);
		if (sub_count > 0)
			total_leds += sub_count;
		else
			total_leds++;
	}

	if (!total_leds)
		return -ENODEV;

	priv = devm_kzalloc(dev, sizeof(*priv) + total_leds * sizeof(struct pwm_channel_led), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->num_leds = total_leds;

	for_each_child_of_node(node, child) {
		u32 group_period = DEFAULT_PWM_PERIOD;
		int sub_count = of_get_child_count(child);

		of_property_read_u32(child, "period", &group_period);

		if (sub_count > 0) {
			/* Group node (e.g. group1 containing blue and orange) */
			for_each_child_of_node(child, channel_node) {
				struct pwm_channel_led *led = &priv->leds[idx];
				const char *label;
				u32 period = group_period;
				int ret;

				of_property_read_u32(channel_node, "period", &period);

				label = of_get_property(channel_node, "label", NULL);
				if (label) {
					snprintf(led->name, sizeof(led->name), "%s", label);
				} else if (!strcmp(channel_node->name, "blue")) {
					snprintf(led->name, sizeof(led->name), "blue:status");
				} else if (!strcmp(channel_node->name, "orange")) {
					snprintf(led->name, sizeof(led->name), "orange:status");
				} else {
					snprintf(led->name, sizeof(led->name), "%s:status", channel_node->name);
				}

				led->pwm = devm_of_pwm_get(dev, channel_node, NULL);
				if (IS_ERR(led->pwm)) {
					ret = PTR_ERR(led->pwm);
					dev_err(dev, "unable to request PWM for %s: %d\n", led->name, ret);
					pwm_rgb_cleanup(priv);
					return ret;
				}

				led->period = period;
				led->cdev.name = led->name;
				led->cdev.brightness_set_blocking = pwm_channel_set_blocking;
				led->cdev.max_brightness = LED_FULL;
				led->cdev.brightness = LED_OFF;

				ret = led_classdev_register_ext(dev, &led->cdev, NULL);
				if (ret) {
					dev_err(dev, "failed to register LED %s: %d\n", led->name, ret);
					pwm_rgb_cleanup(priv);
					return ret;
				}

				dev_info(dev, "Registered PWM status LED: %s (period %u ns)\n", led->name, period);
				idx++;
			}
		} else {
			/* Direct channel node */
			struct pwm_channel_led *led = &priv->leds[idx];
			const char *label;
			u32 period = group_period;
			int ret;

			label = of_get_property(child, "label", NULL);
			if (label)
				snprintf(led->name, sizeof(led->name), "%s", label);
			else
				snprintf(led->name, sizeof(led->name), "%s:status", child->name);

			led->pwm = devm_of_pwm_get(dev, child, NULL);
			if (IS_ERR(led->pwm)) {
				ret = PTR_ERR(led->pwm);
				dev_err(dev, "unable to request PWM for %s: %d\n", led->name, ret);
				pwm_rgb_cleanup(priv);
				return ret;
			}

			led->period = period;
			led->cdev.name = led->name;
			led->cdev.brightness_set_blocking = pwm_channel_set_blocking;
			led->cdev.max_brightness = LED_FULL;
			led->cdev.brightness = LED_OFF;

			ret = led_classdev_register_ext(dev, &led->cdev, NULL);
			if (ret) {
				dev_err(dev, "failed to register LED %s: %d\n", led->name, ret);
				pwm_rgb_cleanup(priv);
				return ret;
			}

			dev_info(dev, "Registered PWM status LED: %s (period %u ns)\n", led->name, period);
			idx++;
		}
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
MODULE_DESCRIPTION("Xiaomi RD15 PWM Status LED driver");
MODULE_LICENSE("GPL");
